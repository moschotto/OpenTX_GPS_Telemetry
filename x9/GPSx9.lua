--[[#############################################################################
GPS Telemetry Screen for Taranis x9d/x9+/x9E (212x64 displays)
Copyright (C) by mosch   
License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html       
GITHUB: https://github.com/moschotto?tab=repositories 

"TELEMETRY screen - GPS last known postions v2.0"  

 
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

log_filename = "/LOGS/GPSpositions.txt"

local gpsLAT = 0
local gpsLON = 0
local gpsLAT_H = 0
local gpsLON_H = 0
local gpsPrevLAT = 0
local gpsPrevLON = 0
local gpsSATS = 0
local gpsFIX = 0
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

local old_time_write2 = 0
local wait = 100

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


local function write_log()

	now = getTime()    
    if old_time_write + log_write_wait_time < now then
	
		ctr = ctr + 1		
		time_power_on = SecondsToClock(getGlobalTimer()["session"])
						
		--write logfile		
		file = io.open(log_filename, "a")    						
		io.write(file, coordinates_current ..",".. time_power_on,"\r\n")			
		io.close(file)			

		if ctr >= 99 then
			ctr = 0				
			--clear log
			file = io.open(log_filename, "w") 
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
	--if Stats can't be read, try to read Tmp2 (number of satellites SBUS/FRSKY)
	if (gpssatId == -1) then gpssatId = getTelemetryId("Tmp2") end	
end

local function background()	

	--####################################################################
	--get Latitude, Longitude
	--####################################################################	
	gpsLatLon = getValue(gpsId)
		
	if (type(gpsLatLon) == "table") then 			
		gpsLAT = rnd(gpsLatLon["lat"],6)
		gpsLON = rnd(gpsLatLon["lon"],6)			
		
		--set home postion only if more than 5 sats available
		if (tonumber(gpsSATS) > 5) then
			gpsLAT_H = rnd(gpsLatLon["pilot-lat"],6)
			gpsLON_H = rnd(gpsLatLon["pilot-lon"],6)	
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
	if (tonumber(gpsSATS) < 2) then gpsFIX = "no GPS fix" end
	if (tonumber(gpsSATS) >= 3) and (tonumber(gpsSATS) <= 4)  then gpsFIX = "GPS 2D fix" end
	if (tonumber(gpsSATS) >= 5) then gpsFIX = "GPS 3D fix" end
	
	
	--####################################################################
	--get calculate distance from home and write log
	--####################################################################			
	if (tonumber(gpsSATS) >= 5) then
	
		if (gpsLAT ~= gpsPrevLAT) and (gpsLON ~=  gpsPrevLON) and (gpsLAT_H ~= 0) and  (gpsLON_H ~= 0) then		
		--if (string.len(gpsLAT) > 4) and  (string.len(gpsLON) > 4) and (tonumber(gpsSATS) > 5) then  
					
			--distance to home
			gpsDtH = rnd(calc_Distance(gpsLAT, gpsLON, gpsLAT_H, gpsLON_H),2)			
			gpsDtH = string.format("%.2f",gpsDtH)		
			
			--total distance traveled					
			if (gpsPrevLAT ~= 0) and  (gpsPrevLON ~= 0) then	
				--print("GPS_Debug_Prev", gpsPrevLAT,gpsPrevLON)	
				--print("GPS_Debug_curr", gpsLAT,gpsLON)	
				
				gpsTotalDist =  rnd(tonumber(gpsTotalDist) + calc_Distance(gpsLAT,gpsLON,gpsPrevLAT,gpsPrevLON),2)			
				gpsTotalDist = string.format("%.2f",gpsTotalDist)					
			end

			--data for displaying the 
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
	
	--reset telemetry data / total distance on "long press enter"
	if event == EVT_ENTER_LONG then
		gpsDtH = 0
		gpsTotalDist = 0
		gpsLAT_H = 0
		gpsLON_H = 0
		
	end 	
	
	-- create screen
	lcd.drawLine(0,0,0,64, SOLID, FORCE)	
	lcd.drawLine(211,0,211,64, SOLID, FORCE)	
	
	lcd.drawText(2,1,"State: " ,SMLSIZE)		
	lcd.drawFilledRectangle(1,0, 210, 8, DEFAULT)
	
	lcd.drawPixmap(2,10, "/SCRIPTS/TELEMETRY/BMP/Sat16.bmp")		
	lcd.drawLine(70,8, 70, 27, SOLID, FORCE)		
	lcd.drawPixmap(72,9, "/SCRIPTS/TELEMETRY/BMP/distance16.bmp")		
	lcd.drawLine(140,8, 140, 27, SOLID, FORCE)	
	lcd.drawPixmap(142,9, "/SCRIPTS/TELEMETRY/BMP/total_distance16.bmp")		
			
	lcd.drawLine(0,27, 211, 27, SOLID, FORCE)
				
	lcd.drawPixmap(2,28, "/SCRIPTS/TELEMETRY/BMP/home16.bmp")		
	lcd.drawLine(0,44, 211, 44, SOLID, FORCE)
			
	lcd.drawPixmap(2,47, "/SCRIPTS/TELEMETRY/BMP/drone16.bmp")
		
	--update screen data
	if update == true then
						
		lcd.drawText(32,1,gpsFIX ,SMLSIZE + INVERS)			
		lcd.drawText(22,12, gpsSATS, MIDSIZE)		
		lcd.drawText(90,12, gpsDtH .. " km", MIDSIZE)	
		lcd.drawText(160,12, gpsTotalDist .. " km", MIDSIZE)	
		
		lcd.drawText(20,33, gpsLAT_H .. ", " .. gpsLON_H, SMLSIZE)
				
		lcd.drawText(20,47, coordinates_prev,SMLSIZE)
		lcd.drawText(20,56, coordinates_current,SMLSIZE)
		
	--blink if telemetry stops
	elseif update == false then
		
		lcd.drawText(32,1,"no GPS data available" ,SMLSIZE + INVERS)
		lcd.drawText(22,12, gpsSATS, MIDSIZE + INVERS + BLINK )		
		lcd.drawText(90,12, gpsDtH .. " km", MIDSIZE + INVERS + BLINK)		
		lcd.drawText(160,12, gpsTotalDist .. " km"  , MIDSIZE)		
		
		lcd.drawText(20,33, gpsLAT_H .. ", " .. gpsLON_H, SMLSIZE)
				
		lcd.drawText(20,47, coordinates_prev, SMLSIZE + INVERS + BLINK)
		lcd.drawText(20,56, coordinates_current, SMLSIZE + INVERS + BLINK)	
		
	end	
end
 
return {init=init, run=run, background=background}
