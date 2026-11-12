--[[#############################################################################
GPS Telemetry Screen for RadioMaster Boxer / Zorro / TX12 / X7 (128x64 displays)
Based on "GPSx9L.lua" by mosch  -  https://github.com/moschotto
Adapted for RadioMaster Boxer + ExpressLRS/Crossfire by saturn-fpv.
License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html

"TELEMETRY screen - GPS last known position + flight telemetry"

Description:
How to find your model in case of a crash, power loss etc? Check the last
GPS coordinates and type them into your phone.

This Boxer version adds, on a 128x64 mono screen and WITHOUT bitmaps:
- Battery voltage per cell (avg)   - Vc
- Drone altitude (m)               - Alt
- Drone ground speed (whole km/h)  - Spd
- Link RSSI in dBm (CRSF 1RSS)     - RSSI
- Link quality % (CRSF RQly)       - LQ
- Battery capacity used (mAh)      - mAh

Still shows: GPS fix state, sats, distance to home, total distance,
home position and the LAST logged GPS position.

- Logs GPS positions to /LOGS/GPSpositions.txt (viewable with GPS Stats Boxer.lua)
- In case telemetry stops, the last coordinates remain on screen
- Reset home position and trip distance via the custom RESET MENU (short-press ENTER / click wheel)
- Transmitter system menu (Reset flight / Reset telemetry) remains available via long-press ENTER

Install:
copy Boxer.lua to /SCRIPTS/TELEMETRY
Setup a "Display" screen and select Boxer
(no BMP folder needed for this version)
################################################################################]]

log_filename = "/LOGS/GPSpositions.txt"

-- ============================ CONFIG =========================================
-- HOME_MODE : how the home point is captured for distance-to-home
--   "hybrid" = set home when the drone ARMS (Betaflight FM telemetry);
--              if no FM sensor exists, fall back to first solid GPS fix. (default)
--   "arm"    = only on arm (FM telemetry). Home stays unset until first arm.
--   "switch" = on a transmitter arm switch/channel going active (set HOME_SWITCH).
--   "fix"    = automatically on the first solid GPS fix after power-up.
--   "manual" = only via short-press ENTER menu.
-- Short-press ENTER opens the manual reset menu in every mode.
local HOME_MODE   = "hybrid"
local HOME_MIN_SATS = 6        -- min satellites before home may be set automatically
local HOME_SWITCH = "sf"       -- only used in "switch" mode: source name e.g. "sa".."sh" or "ch5"
local HOME_SWITCH_ON = 512     -- switch value (>= this = armed). getValue switch range is -1024..1024
-- Ground speed unit: CRSF/ELRS GSpd is already km/h -> 1.0 ;  FrSky GSpd is knots -> 1.852
local SPEED_MULT  = 1.0
-- =============================================================================

local gpsLAT = 0
local gpsLON = 0
local gpsLAT_H = 0
local gpsLON_H = 0
local gpsPrevLAT = 0
local gpsPrevLON = 0
local gpsSATS = 0
local gpsALT = 0
local gpsSpeed = 0
local gpsVcell = 0
local gpsRSSI = 0
local gpsLQ = 0
local gpsmAh = 0
local gpssatId = 0
local gpsspeedId = 0
local gpsaltId = 0
local gpsvbatId = 0
local gpsrssiId = 0
local gpslqId = 0
local gpsmahId = 0
local gpsfmId = 0
local gpsFIX = 0
local gpsArmed = false
local wasArmed = false
local homePending = false
local gpsDtH = 0
local gpsTotalDist = 0
local log_write_wait_time = 10
local old_time_write = 0
local update = true
local string_gmatch = string.gmatch
local now = 0
local ctr = 0
local coordinates_prev = 0
local coordinates_current = 0

local menuOpen = false
local menuSelection = 1

local old_time_write2 = 0
local wait = 100

local function rnd(v,d)
	-- NB: 0 is truthy in Lua, so d==0 must not take the divide branch:
	-- x/(10^0) yields a float and renders as "54.0" instead of "54".
	if d and d > 0 then
		return math.floor((v*10^d)+0.5)/(10^d)
	else
		return math.floor(v+0.5)
	end
end

local function SecondsToClock(seconds)
  local seconds = tonumber(seconds)

  if seconds <= 0 then
    return "00:00:00";
  else
    hours = string.format("%02.f", math.floor(seconds/3600));
    mins = string.format("%02.f", math.floor(seconds/60 - (hours*60)));
    secs = string.format("%02.f", math.floor(seconds - hours*3600 - mins *60));
	return hours..":"..mins..":"..secs
  end
end


local function write_log()

	now = getTime()
    if old_time_write + log_write_wait_time < now then

		ctr = ctr + 1
		time_power_on = SecondsToClock(getGlobalTimer()["session"])

		--write logfile
		file = io.open(log_filename, "a")
		io.write(file, coordinates_current ..",".. time_power_on ..", "..  gpsSATS..", ".. gpsALT ..", ".. gpsSpeed, "\r\n")
		io.close(file)

		if ctr >= 99 then
			ctr = 0
			--clear log
			file = io.open(log_filename, "w")
				io.write(file, "Number,LAT,LON,radio_time,satellites,GPSalt,GPSspeed", "\r\n")
			io.close(file)

			--reopen log for appending data
			file = io.open(log_filename, "a")
		end
		old_time_write = now
	end
end


local function getTelemetryId(name)
	field = getFieldInfo(name)
	if field then
		return field.id
	else
		return-1
	end
end


--[	####################################################################
--[	calculate distance
--[	####################################################################
local function calc_Distance(LatPos, LonPos, LatHome, LonHome)
	local d2r = math.pi/180
	local d_lon = (LonPos - LonHome) * d2r
	local d_lat = (LatPos - LatHome) * d2r
	local a = math.pow(math.sin(d_lat/2.0), 2) + math.cos(LatHome*d2r) * math.cos(LatPos*d2r) * math.pow(math.sin(d_lon/2.0), 2)
	local c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
	local dist = (6371000 * c) / 1000
	return rnd(dist,2)
end

local function init()
	gpsId = getTelemetryId("GPS")
	--number of satellites crossfire
	gpssatId = getTelemetryId("Sats")

	--get IDs GPS Speed and altitude
	gpsspeedId = getTelemetryId("GSpd") --GPS ground speed (knots)
	gpsaltId = getTelemetryId("Alt")    --barometric / estimated altitude (m)

	--if "Alt" can't be read, try to read "GAlt" (GPS altitude)
	if (gpsaltId == -1) then gpsaltId = getTelemetryId("GAlt") end

	--if Sats can't be read, try Tmp2 (number of satellites SBUS/FRSKY)
	if (gpssatId == -1) then gpssatId = getTelemetryId("Tmp2") end

	--battery voltage (ELRS/CRSF reports RxBt). Fallbacks for FrSky.
	gpsvbatId = getTelemetryId("RxBt")
	if (gpsvbatId == -1) then gpsvbatId = getTelemetryId("Cels") end
	if (gpsvbatId == -1) then gpsvbatId = getTelemetryId("VFAS") end

	--RSSI in dBm (CRSF/ELRS uplink antenna 1)
	gpsrssiId = getTelemetryId("1RSS")
	if (gpsrssiId == -1) then gpsrssiId = getTelemetryId("RSS") end
	if (gpsrssiId == -1) then gpsrssiId = getTelemetryId("RSSI") end

	--link quality % (CRSF/ELRS uplink)
	gpslqId = getTelemetryId("RQly")
	if (gpslqId == -1) then gpslqId = getTelemetryId("RQLY") end

	--battery capacity used in mAh (CRSF/ELRS battery frame). Fallbacks for FrSky.
	gpsmahId = getTelemetryId("Capa")
	if (gpsmahId == -1) then gpsmahId = getTelemetryId("mAh") end
	if (gpsmahId == -1) then gpsmahId = getTelemetryId("Fuel") end

	--flight mode string (used to detect arming on Betaflight/CRSF)
	gpsfmId = getTelemetryId("FM")
	if (gpsfmId == -1) then gpsfmId = getTelemetryId("FltM") end
	if (gpsfmId == -1) then gpsfmId = getTelemetryId("Mode") end
end

--[	####################################################################
--[	armed detection
--[	####################################################################
-- Betaflight CRSF flight-mode string carries a trailing marker ONLY when
-- disarmed:  '*' ready to arm, '!' arming disabled, '?' gps-rescue not ready.
-- Armed -> the mode text ("ANGL","ACRO","AIR","RTH"...) has no trailing marker.
-- Returns true (armed), false (disarmed) or nil (unknown / no FM sensor).
local function isArmed()
	if (gpsfmId == -1) then return nil end
	local fm = getValue(gpsfmId)
	if (type(fm) ~= "string") or (fm == "") then return nil end
	if (fm == "!FS!") then return true end           -- failsafe = in the air
	local last = string.sub(fm, -1)
	if (last == "*") or (last == "!") or (last == "?") then
		return false
	end
	return true
end

-- Reads the transmitter arm switch/channel (only used in "switch" mode)
local function switchArmed()
	local id = getTelemetryId(HOME_SWITCH)
	local v
	if (id ~= -1) then v = getValue(id) else v = getValue(HOME_SWITCH) end
	if (type(v) ~= "number") then return nil end
	return v >= HOME_SWITCH_ON
end

local function background()

	--####################################################################
	--link telemetry (independent of GPS lock): voltage, RSSI, LQ
	--####################################################################
	gpsRSSI = getValue(gpsrssiId)
	gpsLQ = getValue(gpslqId)

	--battery capacity used (mAh). Missing sensor / bad value -> keep last reading.
	if (gpsmahId ~= -1) then
		local rawMah = getValue(gpsmahId)
		if (type(rawMah) == "table") then rawMah = rawMah[1] end
		if (type(rawMah) == "number") and (rawMah >= 0) then
			gpsmAh = rnd(rawMah,0)
		end
	end

	local rawV = getValue(gpsvbatId)
	if (type(rawV) == "table") then rawV = rawV[1] end
	if (type(rawV) == "number") and rawV > 0 then
		if rawV > 4.5 then
			--looks like a pack voltage -> estimate cells and average
			local cells = math.ceil(rawV / 4.35)
			if cells < 1 then cells = 1 end
			gpsVcell = rnd(rawV / cells, 2)
		else
			--already a per-cell value
			gpsVcell = rnd(rawV, 2)
		end
	else
		gpsVcell = 0
	end

	--####################################################################
	--get Latitude, Longitude, Speed and Altitude
	--####################################################################
	gpsLatLon = getValue(gpsId)

	if (type(gpsLatLon) == "table") then
		gpsLAT = rnd(gpsLatLon["lat"],6)
		gpsLON = rnd(gpsLatLon["lon"],6)
		gpsSpeed = rnd(getValue(gpsspeedId) * SPEED_MULT,0)
		gpsALT = rnd(getValue(gpsaltId),0)

		update = true
	else
		update = false
	end

	--####################################################################
	--get number of satellites and GPS fix type
	--####################################################################
	gpsSATS = getValue(gpssatId)

	if string.len(gpsSATS) > 2 then
		-- SBUS Example 1013: -> 1= GPS fix 0=lowest accuracy 13=13 active satellites
		gpsSATS = string.sub (gpsSATS, 3,6)
	else
		--CROSSFIRE stores only the active GPS satellite count
		gpsSATS = string.sub (gpsSATS, 0,3)
	end

	--status message "guess"
	if (tonumber(gpsSATS) < 2) then gpsFIX = "no GPS fix" end
	if (tonumber(gpsSATS) >= 3) and (tonumber(gpsSATS) <= 4)  then gpsFIX = "GPS 2D fix" end
	if (tonumber(gpsSATS) >= 5) then gpsFIX = "GPS 3D fix" end


	--####################################################################
	--automatic home point handling (arm / first-fix / switch / manual)
	--####################################################################
	-- determine current armed state for the selected mode
	local armed = nil
	if (HOME_MODE == "switch") then
		armed = switchArmed()
	else
		armed = isArmed()
	end

	-- rising edge disarmed->armed requests a fresh home capture
	if (armed == true) and (wasArmed == false) then
		homePending = true
	end
	if (armed ~= nil) then
		gpsArmed = armed
		wasArmed = armed
	end

	-- in hybrid/fix mode, set home on the first solid fix if it is still unset
	local useFirstFix = (HOME_MODE == "fix")
		or (HOME_MODE == "hybrid" and gpsfmId == -1)

	if (type(gpsLatLon) == "table") and (tonumber(gpsSATS) >= HOME_MIN_SATS) then
		if (homePending == true) then
			gpsLAT_H = gpsLAT
			gpsLON_H = gpsLON
			gpsPrevLAT = gpsLAT          -- avoid a huge first trip segment
			gpsPrevLON = gpsLON
			gpsTotalDist = 0             -- new flight: reset trip distance
			gpsDtH = 0
			homePending = false
		elseif (useFirstFix == true) and (gpsLAT_H == 0) and (gpsLON_H == 0) then
			gpsLAT_H = gpsLAT
			gpsLON_H = gpsLON
			gpsPrevLAT = gpsLAT
			gpsPrevLON = gpsLON
		end
	end


	--####################################################################
	--calculate distance from home and write log
	--####################################################################
	if (tonumber(gpsSATS) >= 5) then

		if (gpsLAT ~= gpsPrevLAT) and (gpsLON ~=  gpsPrevLON) then

			if (gpsLAT_H ~= 0) and  (gpsLON_H ~= 0) then

				--distance to home
				gpsDtH = rnd(calc_Distance(gpsLAT, gpsLON, gpsLAT_H, gpsLON_H),2)
				gpsDtH = string.format("%.2f",gpsDtH)

				--total distance traveled
				if (gpsPrevLAT ~= 0) and  (gpsPrevLON ~= 0) and (gpsLAT ~= 0) and  (gpsLON ~= 0)then
					gpsTotalDist =  rnd(tonumber(gpsTotalDist) + calc_Distance(gpsLAT,gpsLON,gpsPrevLAT,gpsPrevLON),2)
					gpsTotalDist = string.format("%.2f",gpsTotalDist)
				end
			end

			--data for displaying the positions
			coordinates_prev = string.format("%02d",ctr) ..", ".. gpsPrevLAT..", " .. gpsPrevLON
			coordinates_current = string.format("%02d",ctr+1) ..", ".. gpsLAT..", " .. gpsLON

			gpsPrevLAT = gpsLAT
			gpsPrevLON = gpsLON

			write_log()
		end
	end


end

--main function
local function run(event)
	lcd.clear()
	background()

	-- manual override menu handling
	if menuOpen then
		if event == EVT_EXIT_BREAK then
			menuOpen = false
		elseif (event == EVT_ROT_RIGHT) or (event == EVT_DOWN_BREAK) or (event == EVT_PLUS_BREAK) then
			menuSelection = 2
		elseif (event == EVT_ROT_LEFT) or (event == EVT_UP_BREAK) or (event == EVT_MINUS_BREAK) then
			menuSelection = 1
		elseif event == EVT_ENTER_BREAK then
			if menuSelection == 1 then
				gpsDtH = 0
				gpsTotalDist = 0
				gpsLAT_H = 0
				gpsLON_H = 0
				gpsPrevLAT = 0
				gpsPrevLON = 0
				homePending = true
			end
			menuOpen = false
		end
	else
		if event == EVT_ENTER_BREAK then
			menuOpen = true
			menuSelection = 1
		end
	end

	-- frame
	lcd.drawLine(0,0,0,63, SOLID, FORCE)
	lcd.drawLine(127,0,127,63, SOLID, FORCE)
	lcd.drawLine(0,63,127,63, SOLID, FORCE)

	-- status bar (inverted): GPS fix state + sats
	lcd.drawFilledRectangle(0,0, 128, 9, GREY_DEFAULT)
	if update == true then
		lcd.drawText(2,1, gpsFIX, SMLSIZE + INVERS)
	else
		lcd.drawText(2,1, "no GPS data", SMLSIZE + INVERS + BLINK)
	end
	if gpsArmed == true then lcd.drawText(62,1, "ARM", SMLSIZE + INVERS) end
	lcd.drawText(86,1, "Sat "..gpsSATS, SMLSIZE + INVERS)

	-- telemetry block (always drawn; link data is valid even without GPS fix)
	lcd.drawText(2,12,  "Vc "..gpsVcell.."V", SMLSIZE)
	lcd.drawText(62,12, "RSSI "..gpsRSSI.."dBm", SMLSIZE)
	lcd.drawText(2,21,  "Alt "..gpsALT.."m", SMLSIZE)
	lcd.drawText(62,21, "LQ "..gpsLQ, SMLSIZE)
	lcd.drawText(2,30,  "Spd "..gpsSpeed.."kmh", SMLSIZE)
	if (gpsmahId ~= -1) then
		lcd.drawText(62,30, "mAh "..gpsmAh, SMLSIZE)
	else
		lcd.drawText(62,30, "mAh --", SMLSIZE)
	end
	lcd.drawText(2,39,  "DtH "..gpsDtH.."km", SMLSIZE)
	lcd.drawText(62,39, "Tot "..gpsTotalDist.."km", SMLSIZE)

	lcd.drawLine(0,46, 127, 46, SOLID, FORCE)

	-- home position
	if (gpsLAT_H ~= 0) and  (gpsLON_H ~= 0) then
		lcd.drawText(2,48, "H "..gpsLAT_H..", "..gpsLON_H, SMLSIZE)
	else
		lcd.drawText(2,48, "home not set-reset@FIX", SMLSIZE + INVERS + BLINK)
	end

	-- last logged GPS position
	if update == true then
		lcd.drawText(2,55, coordinates_current, SMLSIZE)
	else
		lcd.drawText(2,55, coordinates_current, SMLSIZE + INVERS + BLINK)
	end

	-- Draw custom popup menu if open
	if menuOpen then
		local boxX = 14
		local boxY = 12
		local boxW = 100
		local boxH = 40

		-- Draw box background and border
		lcd.drawFilledRectangle(boxX, boxY, boxW, boxH, ERASE)
		lcd.drawRectangle(boxX, boxY, boxW, boxH, FORCE)

		-- Draw box header
		lcd.drawFilledRectangle(boxX + 2, boxY + 2, boxW - 4, 10, FORCE)
		lcd.drawText(boxX + 18, boxY + 3, "RESET MENU", SMLSIZE + INVERS)

		-- Draw menu options
		if menuSelection == 1 then
			lcd.drawFilledRectangle(boxX + 6, boxY + 15, boxW - 12, 9, FORCE)
			lcd.drawText(boxX + 10, boxY + 16, "Reset Home", SMLSIZE + INVERS)
			lcd.drawText(boxX + 10, boxY + 26, "Cancel", SMLSIZE)
		else
			lcd.drawText(boxX + 10, boxY + 16, "Reset Home", SMLSIZE)
			lcd.drawFilledRectangle(boxX + 6, boxY + 25, boxW - 12, 9, FORCE)
			lcd.drawText(boxX + 10, boxY + 26, "Cancel", SMLSIZE + INVERS)
		end
	end

end

return {init=init, run=run, background=background}
