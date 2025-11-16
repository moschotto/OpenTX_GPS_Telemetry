--[[#############################################################################
GPS Telemetry Screen for Taranis x7 / x9 lite (128x64 displays)
Copyright (C) by mosch   
License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html       
GITHUB: https://github.com/moschotto?tab=repositories 

"TELEMETRY screen - GPS last known postions v2.5"  

 
Description:
How to find your model in case of a crash, power loss etc? Right, check the last 
GPS coordinates and type it into to your mobile phone...

- Shows and logs GPS related information. log file will be generated in
/LOGS/GPSpositions.txt

- GPS logfile can be viewed with the GPSviewer.lua" (check github) on the radio

- in case that the telemetry stops, the last coordinates will remain on the screen

- distance to your home position - how far you need to walk ;)

- Reset telemetry data and total distance via "long press enter"

Install:
copy GPS.lua to /SCRIPTS/TELEMETRY
copy the ICON folder to /SCRIPTS/TELEMETRY/BMP
Setup a "screen (DIsplay 13/13)" and select GPS.lua

################################################################################]]

local gpsLAT = 0
local gpsLON = 0
local gpsHdg = 0
local gpsLAT_H = 0
local gpsLON_H = 0
local gpsPrevLAT = 0
local gpsPrevLON = 0
local gpsSATS = 0
local gpsALT = 0
local gpsSpeed = 0
local gpssatId = 0
local gpsspeedId = 0
local gpsHdgId = 0
local gpsaltId = 0
local gpsFIX = 0
local gpsDtH = 0
local gpsTotalDist = 0
local log_write_wait_time = 100
local old_time_write = 0
local update = true
local reset = false
local string_gmatch = string.gmatch
local now = 0
local ctr = 0
local coordinates_prev = 0
local coordinates_current = 0

local old_time_write2 = 0
local wait = 100

-- GPX save
local armed
local chArmedId
local waypoints_recorded = 0
local gpx_path = ""
local log_file = nil

-- Pop up save GPX
local popup_active = false
local selec = 1          -- 0 = Yes, 1 = No
local result = "No"
local mid = LCD_W / 2  -- Center alignment for LCD display

local function rnd(v,d)
	if d then
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

local function write_gps_file_header()
	local dt = getDateTime()		
	local timestamp = string.format(
	"%d-%02d-%02dT%02d:%02d:%02d",
	tonumber(dt.year), tonumber(dt.mon ), tonumber(dt.day),
	tonumber(dt.hour), tonumber(dt.min ), tonumber(dt.sec))
		
	io.write(log_file, "<?xml version='1.0' encoding='UTF-8'?>\n")
	io.write(log_file, "<gpx version='1.1' creator='EdgeTX Lua Script' xmlns='http://www.topografix.com/GPX/1/1'>\n")	
	io.write(log_file, string.format("<metadata><time>%s</time></metadata>\n", timestamp))
	io.write(log_file, string.format("<trk><name>Flight Log</name><trkseg>\n", timestamp))
end

local function write_gps_file_footer()
	io.write(log_file, "</trkseg></trk>\n</gpx>")
end

-- Draw popup for savig GPX
local function drawPopup()
  -- Popup
  lcd.drawFilledRectangle(25, 15, mid+10, 40, ERASE)
  lcd.drawRectangle(25, 15, mid+10, 40, FORCE)
  lcd.drawText(mid - 30, 20, "¿Save GPX?", 0)
  lcd.drawText(mid - 25, 38, "Yes",   selec == 0 and INVERS or 0)
  lcd.drawText(mid + 5, 38, "No",   selec == 1 and INVERS or 0)
end

local function stopLog()
	if waypoints_recorded < 6 then -- no point in storing empty (or very small) logs
		io.close(log_file)
		del(gpx_path)	
		result = "Exit"
	else
		write_gps_file_footer()
		io.close(log_file)
		result = "Done"
	end
	
	log_file = nil
	gpx_path = ""
	waypoints_recorded = 0	
end

local function write_log()

	now = getTime()    

	-- Generate GPX file
	armed = getValue(chArmedId) > 0
	
	if log_file == nil and armed and selec == 0 then	
		result="?"	
		local dt = getDateTime()		
		local timestamp = string.format(
		"%d-%02d-%02d_%02d_%02d_%02d",
		tonumber(dt.year), tonumber(dt.mon), tonumber(dt.day),
		tonumber(dt.hour), tonumber(dt.min), tonumber(dt.sec))
		
		gpx_path = string.format("/LOGS/gps_log_%s.gpx", timestamp)			
		log_file = io.open(gpx_path, "a")	
		waypoints_recorded = 0

		write_gps_file_header()
	end	
		
	if not armed and log_file ~= nil and selec == 0 then
		stopLog()
	end
			
	if armed and selec == 0 and old_time_write + log_write_wait_time < now then	
		local dt = getDateTime()
		local timestamp = string.format(
		"%d-%02d-%02dT%02d:%02d:%02d",
		tonumber(dt.year), tonumber(dt.mon), tonumber(dt.day),
		tonumber(dt.hour), tonumber(dt.min), tonumber(dt.sec))
					
		io.write(log_file, string.format(
		"<trkpt lat='%f' lon='%f'><ele>%f</ele><sat>%f</sat><magvar>%f</magvar><time>%s</time></trkpt>\n", 
		gpsLAT, gpsLON, gpsALT, gpsSATS, gpsHdg, timestamp))
		
		waypoints_recorded = waypoints_recorded + 1
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
	-- Magnetic Orientation
	gpsHdgId = getTelemetryId("Hdg")

	--get IDs GPS Speed and GPS altitude
	gpsspeedId = getTelemetryId("GSpd") --GPS ground speed m/s
	gpsaltId = getTelemetryId("Alt") --GPS altitude m
		
	--if "ALT" can't be read, try to read "GAlt"
	if (gpsaltId == -1) then gpsaltId = getTelemetryId("GAlt") end	
		
	--if Stats can't be read, try to read Tmp2 (number of satellites SBUS/FRSKY)
	if (gpssatId == -1) then gpssatId = getTelemetryId("Tmp2") end	
	chArmedId = getFieldInfo('ch5').id
end

local function background()	

	--####################################################################
	--get Latitude, Longitude, Speed, Hdg and Altitude
	--####################################################################	
	gpsLatLon = getValue(gpsId)
	gpsHdg = getValue(gpsHdgId)	
	
	if (type(gpsLatLon) == "table") then 			
		gpsLAT = rnd(gpsLatLon["lat"],6)
		gpsLON = rnd(gpsLatLon["lon"],6)		
		gpsSpeed = rnd(getValue(gpsspeedId) * 1.852,1)
		gpsALT = rnd(getValue(gpsaltId),0)		
				
		--set home postion only if more than 5 sats available
		if (tonumber(gpsSATS) > 5) and (reset == true) then
			--gpsLAT_H = rnd(gpsLatLon["pilot-lat"],6)
			--gpsLON_H = rnd(gpsLatLon["pilot-lon"],6)	
			gpsLAT_H = rnd(gpsLatLon["lat"],6)
			gpsLON_H = rnd(gpsLatLon["lon"],6)	
			reset = false
		end		

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
		--[	Sats / Tmp2 : GPS lock status, accuracy, home reset trigger, and number of satellites. Number is sent as ABCD detailed below. Typical minimum 
		--[	A : 1 = GPS fix, 2 = GPS home fix, 4 = home reset (numbers are additive)
		--[	B : GPS accuracy based on HDOP (0 = lowest to 9 = highest accuracy)
		--[	C : number of satellites locked (digit C & D are the number of locked satellites)
		--[ D : number of satellites locked (if 14 satellites are locked, C = 1 & D = 4)		
		gpsSATS = string.sub (gpsSATS, 3,6)		
	else
		--CROSSFIRE stores only the active GPS satellite
		gpsSATS = string.sub (gpsSATS, 0,3)		
	end	
	
	--status message "guess"
	-- 2D Mode - A 2D (two dimensional) position fix that includes only horizontal coordinates. It requires a minimum of three visible satellites.)
	-- 3D Mode - A 3D (three dimensional) position fix that includes horizontal coordinates plus altitude. It requires a minimum of four visible satellites.
	if (tonumber(gpsSATS) < 2) then gpsFIX = "no fix" end
	if (tonumber(gpsSATS) >= 3) and (tonumber(gpsSATS) <= 4)  then gpsFIX = "2D fix" end
	if (tonumber(gpsSATS) >= 5) then gpsFIX = "3D fix" end
	
	
	--####################################################################
	--get calculate distance from home and write log
	--####################################################################			
	if (tonumber(gpsSATS) >= 5) then
	
		if (gpsLAT ~= gpsPrevLAT) or (gpsLON ~=  gpsPrevLON) then				
			
			if (gpsLAT_H ~= 0) and  (gpsLON_H ~= 0) then 
			
				--distance to home
				gpsDtH = rnd(calc_Distance(gpsLAT, gpsLON, gpsLAT_H, gpsLON_H),2)			
				gpsDtH = string.format("%.2f",gpsDtH)		
				
				--total distance traveled					
				if (gpsPrevLAT ~= 0) and  (gpsPrevLON ~= 0) and (gpsLAT ~= 0) and  (gpsLON ~= 0)then
					--print("GPS_Debug_Prev", gpsPrevLAT,gpsPrevLON)	
					--print("GPS_Debug_curr", gpsLAT,gpsLON)	
					
					gpsTotalDist =  rnd(tonumber(gpsTotalDist) + calc_Distance(gpsLAT,gpsLON,gpsPrevLAT,gpsPrevLON),2)			
					gpsTotalDist = string.format("%.2f",gpsTotalDist)					
				end
			end

			--data for displaying the 
			coordinates_prev = string.format("%02d",ctr) ..", ".. gpsPrevLAT..", " .. gpsPrevLON
			coordinates_current = string.format("%02d",ctr+1) ..", ".. gpsLAT..", " .. gpsLON 
											
			gpsPrevLAT = gpsLAT
			gpsPrevLON = gpsLON	
		end 
	end
	
	if (tonumber(gpsSATS) >= 3) then 
		write_log()
	end
	
	
end

--main function 
local function run(event)  
	lcd.clear()  
	background() 
	
	--reset telemetry data / total distance on "long press enter"
	if event == EVT_ENTER_LONG then
		gpsDtH = 0
		gpsTotalDist = 0
		gpsLAT_H = 0
		gpsLON_H = 0
		reset = true
		
	end 	
	
	-- create screen
	lcd.drawLine(0,0,0,64, SOLID, FORCE)	
	lcd.drawLine(127,0,127,64, SOLID, FORCE)	
	
	lcd.drawText(2,1,"State: " ,SMLSIZE)		
	lcd.drawFilledRectangle(1,0, 126, 8, GREY_DEFAULT)
	
	lcd.drawPixmap(2,10, "/SCRIPTS/TELEMETRY/BMP/Sat16.bmp")		
	lcd.drawLine(42,8, 42, 27, SOLID, FORCE)		
	lcd.drawPixmap(44,9, "/SCRIPTS/TELEMETRY/BMP/distance16.bmp")		
	lcd.drawLine(84,8, 84, 27, SOLID, FORCE)	
	lcd.drawPixmap(86,9, "/SCRIPTS/TELEMETRY/BMP/total_distance16.bmp")		
			
	lcd.drawLine(0,27, 128, 27, SOLID, FORCE)
				
	lcd.drawPixmap(2,28, "/SCRIPTS/TELEMETRY/BMP/home16.bmp")		
	lcd.drawLine(0,44, 128, 44, SOLID, FORCE)
			
	lcd.drawPixmap(2,47, "/SCRIPTS/TELEMETRY/BMP/drone16.bmp")
	lcd.drawLine(0,63,127,63, SOLID, FORCE)		
	
	--update screen data
	if update == true then
						
		lcd.drawText(32,1,gpsFIX ,SMLSIZE + INVERS)	
		lcd.drawText(25+(8*5),1,"Save GPX: " ,SMLSIZE + INVERS)
		if waypoints_recorded > 0 then
			lcd.drawText(27+(6*5)+(10*5),1,waypoints_recorded ,SMLSIZE + INVERS)
		else
			lcd.drawText(27+(6*5)+(10*5),1,result ,SMLSIZE + INVERS)
		end		
		lcd.drawText(22,14, gpsSATS, SMLSIZE)		
		lcd.drawText(60,10, gpsDtH, SMLSIZE)
		lcd.drawText(73,20, "km"  , SMLSIZE)
		lcd.drawText(103,10, gpsTotalDist, SMLSIZE)
		lcd.drawText(116,20, "km"  , SMLSIZE)
		
		if (gpsLAT_H ~= 0) and  (gpsLON_H ~= 0) then
			lcd.drawText(20,33, gpsLAT_H .. ", " .. gpsLON_H, SMLSIZE)
		else
			lcd.drawText(20,29, "home not set. reset", SMLSIZE + INVERS + BLINK)
			lcd.drawText(20,37, "telem. after GPS FIX!", SMLSIZE + INVERS + BLINK)
		end
				
		lcd.drawText(20,47, coordinates_prev,SMLSIZE)
		lcd.drawText(20,56, coordinates_current,SMLSIZE)
		
	--blink if telemetry stops
	elseif update == false then
		
		lcd.drawText(32,1,"no GPS" ,SMLSIZE + INVERS)
		lcd.drawText(25+(8*5),1,"Save GPX: " ,SMLSIZE + INVERS)
		if waypoints_recorded > 0 then
			lcd.drawText(27+(6*5)+(10*5),1,waypoints_recorded ,SMLSIZE + INVERS)
		else
			lcd.drawText(27+(6*5)+(10*5),1,result ,SMLSIZE + INVERS)
		end
		lcd.drawText(22,14, gpsSATS, SMLSIZE + INVERS + BLINK )		
		lcd.drawText(60,10, gpsDtH , SMLSIZE + INVERS + BLINK)
		lcd.drawText(73,20, "km"  , SMLSIZE)
		lcd.drawText(103,10, gpsTotalDist , SMLSIZE)
		lcd.drawText(116,20, "km"  , SMLSIZE)		
		
		lcd.drawText(20,33, gpsLAT_H .. ", " .. gpsLON_H, SMLSIZE)
				
		lcd.drawText(20,47, coordinates_prev, SMLSIZE + INVERS + BLINK)
		lcd.drawText(20,56, coordinates_current, SMLSIZE + INVERS + BLINK)	
		
	end	
	if not popup_active then
		if event == EVT_ENTER_BREAK then
			popup_active = true
			result="?"
		end
	else
		drawPopup()
		-- Popup events
		if event == EVT_PLUS_BREAK or event == EVT_ROT_RIGHT then
		  selec = 1
		elseif event == EVT_MINUS_BREAK or event == EVT_ROT_LEFT then
		  selec = 0
		elseif event == EVT_ENTER_BREAK then
			if selec == 0 then
				result = "Yes"
			else
				result = "No"
				if waypoints_recorded > 0 then
					stopLog()
				end
			end
		  popup_active = false
		elseif event == EVT_EXIT_BREAK then
		  popup_active = false
		end
	end
end
 
return {init=init, run=run, background=background}
