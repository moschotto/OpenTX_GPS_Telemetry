--[[#############################################################################
GPS Telemetry Widget for Jumper TX16 etc (480x272 displays)
Copyright (C) by mosch   
License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html       
GITHUB: https://github.com/moschotto?tab=repositories 

"TELEMETRY screen - GPS last known postions v2.3"  

 
Description:
How to find your model in case of a crash, power loss etc? Right, check the last 
GPS coordinates and type it into to your mobile phone...

- Shows and logs GPS related information. log file will be generated in
/LOGS/GPSpositions.txt

- GPS logfile can be viewed with the GPSviewer.lua" (check github) on the radio

- in case that the telemetry stops, the last coordinates will remain on the screen

- distance to your home position - how far you need to walk ;)

- Reset telemetry DOES NOT WORK in HOROUS/JUMPER - event not implemented yet
  Turn off/on to reset telem. data

Install:
- copy the GPS folder (inculding subfolders) to /WIDGETS/GPS
- Setup 1/2 widget screen and select "GPS"

################################################################################]]


log_filename = "/LOGS/GPSpositions.txt"
local sat_img 
local dis_img 
local disT_img 
local home_img  
local drone_img



--[	####################################################################
--[	functions
--[	####################################################################

	--[	####################################################################
	--[	rounding function
	--[	####################################################################

	local function rnd(v,d)
		if d then
			return math.floor((v*10^d)+0.5)/(10^d)
		else
			return math.floor(v+0.5)
		end
	end

	--[	####################################################################
	--[	seconds format
	--[	####################################################################

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
	
	--[	####################################################################
	--[	write logfile
	--[	####################################################################
	local function write_log(wgt)

		now = getTime()    
		if wgt.old_time_write + wgt.log_write_wait_time < now then
		
			wgt.ctr = wgt.ctr + 1		
			time_power_on = SecondsToClock(getGlobalTimer()["session"])
							
			--write logfile		
			file = io.open(log_filename, "a")    									
			io.write(file, wgt.coordinates_current ..",".. time_power_on ..", "..  wgt.gpsSATS, "\r\n")		
			io.close(file)			

			if wgt.ctr >= 99 then
				wgt.ctr = 0				
				--clear log
				file = io.open(log_filename, "w") 
				io.close(file)	
				
				--reopen log for appending data
				file = io.open(log_filename, "a")    			
			end	
			wgt.old_time_write = now
		end	
	end

	--[	####################################################################
	--[	get telemetry IDs
	--[	####################################################################

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
	

--############################################################################
local options = {
  { "LineColor", COLOR, WHITE },
  { "TextColor", COLOR, BLACK }
}

local function create(zone, options)
	local wgt = { 
	zone=zone, 
	options=options, 
	counter=0,		
	gpsId=0,
	gpssatId=0,	
	gpsLAT = 0,
	gpsLON = 0,
	gpsLAT_H = 0,
	gpsLON_H = 0,
	gpsPrevLAT = 0,
	gpsPrevLON = 0,
	gpsSATS = 0,
	gpsFIX = 0,
	gpsDtH = 0,
	gpsTotalDist = 0,
	log_write_wait_time = 10,
	old_time_write = 0,
	update = true,
	string_gmatch = string.gmatch,
	now = 0,
	ctr = 0,
	coordinates_prev = 0,
	coordinates_current = 0,
	old_time_write2 = 0,
	wait = 100,
	sat_img = 0,
	drone_img = 0,
	home_img = 0,
	dis_img = 0,
	disT_img = 0	
	}
		
	--load images
	sat_img = Bitmap.open("/WIDGETS/GPS/BMP/sat128.png")
	dis_img = Bitmap.open("/WIDGETS/GPS/BMP/distance128.png")
	disT_img = Bitmap.open("/WIDGETS/GPS/BMP/distanceT128.png")
	home_img = Bitmap.open("/WIDGETS/GPS/BMP/home128.png")
	drone_img = Bitmap.open("/WIDGETS/GPS/BMP/drone128.png")
	
		
	return wgt
end

local function update(wgt, options)

	if (wgt == nil) then		
		print("GPS_Debug", "Widget not initialized - 1")	
		return
	end
	
	wgt.options = options   
  	
	lcd.setColor(TEXT_COLOR, wgt.options.TextColor)
	lcd.setColor(LINE_COLOR, wgt.options.LineColor)
		
end

local function background(wgt)
	return
end

local function get_data(wgt)
      
	  
	--####################################################################
	--get Sensor IDs
	--####################################################################		
	wgt.gpsId = getTelemetryId("GPS")
	
	--number of satellites crossfire
	wgt.gpssatId = getTelemetryId("Sats")
	
	--if Stats can't be read, try to read Tmp2 (number of satellites SBUS/FRSKY)
	if (wgt.gpssatId == -1) then wgt.gpssatId = getTelemetryId("Tmp2") end	
		  
	  
	--####################################################################
	--get Latitude, Longitude
	--####################################################################		
	wgt.gpsLatLon = getValue(wgt.gpsId)
		
	if (type(wgt.gpsLatLon) == "table") then 			
		wgt.gpsLAT = rnd(wgt.gpsLatLon["lat"],6)
		wgt.gpsLON = rnd(wgt.gpsLatLon["lon"],6)		
			
		
		--set home postion only if more than 5 sats available
		if (tonumber(wgt.gpsSATS) > 5) then
			wgt.gpsLAT_H = rnd(wgt.gpsLatLon["pilot-lat"],6)
			wgt.gpsLON_H = rnd(wgt.gpsLatLon["pilot-lon"],6)	
		end

		wgt.update = true	
	else
		wgt.update = false
	end
	
	--####################################################################
	--get number of satellites and GPS fix type
	--####################################################################	
	wgt.gpsSATS = getValue(wgt.gpssatId)
	
	if string.len(wgt.gpsSATS) > 2 then		
		-- SBUS Example 1013: -> 1= GPS fix 0=lowest accuracy 13=13 active satellites
		--[	Sats / Tmp2 : GPS lock status, accuracy, home reset trigger, and number of satellites. Number is sent as ABCD detailed below. Typical minimum 
		--[	A : 1 = GPS fix, 2 = GPS home fix, 4 = home reset (numbers are additive)
		--[	B : GPS accuracy based on HDOP (0 = lowest to 9 = highest accuracy)
		--[	C : number of satellites locked (digit C & D are the number of locked satellites)
		--[ D : number of satellites locked (if 14 satellites are locked, C = 1 & D = 4)		
		wgt.gpsSATS = string.sub (wgt.gpsSATS, 3,6)		
	else
		--CROSSFIRE stores only the active GPS satellite
		wgt.gpsSATS = string.sub (wgt.gpsSATS, 0,3)		
	end	
	
	--status message "guess"
	-- 2D Mode - A 2D (two dimensional) position fix that includes only horizontal coordinates. It requires a minimum of three visible satellites.)
	-- 3D Mode - A 3D (three dimensional) position fix that includes horizontal coordinates plus altitude. It requires a minimum of four visible satellites.
	if (tonumber(wgt.gpsSATS) < 2) then wgt.gpsFIX = "no GPS fix" end
	if (tonumber(wgt.gpsSATS) >= 3) and (tonumber(wgt.gpsSATS) <= 4)  then wgt.gpsFIX = "GPS 2D fix" end
	if (tonumber(wgt.gpsSATS) >= 5) then wgt.gpsFIX = "GPS 3D fix" end
	
	
	--####################################################################
	--get calculate distance from home and write log
	--####################################################################			
	if (tonumber(wgt.gpsSATS) >= 5) then
	
		if (wgt.gpsLAT ~= wgt.gpsPrevLAT) and (wgt.gpsLON ~=  wgt.gpsPrevLON) and (wgt.gpsLAT_H ~= 0) and  (wgt.gpsLON_H ~= 0) then		
		--if (string.len(gpsLAT) > 4) and  (string.len(gpsLON) > 4) and (tonumber(gpsSATS) > 5) then  
					
			--distance to home
			wgt.gpsDtH = rnd(calc_Distance(wgt.gpsLAT, wgt.gpsLON, wgt.gpsLAT_H, wgt.gpsLON_H),2)			
			wgt.gpsDtH = string.format("%.2f",wgt.gpsDtH)		
			
			--total distance traveled					
			if (wgt.gpsPrevLAT ~= 0) and  (wgt.gpsPrevLON ~= 0) then	
				
				wgt.gpsTotalDist =  rnd(tonumber(wgt.gpsTotalDist) + calc_Distance(wgt.gpsLAT,wgt.gpsLON,wgt.gpsPrevLAT,wgt.gpsPrevLON),2)			
				wgt.gpsTotalDist = string.format("%.2f",wgt.gpsTotalDist)					
			end

			--data for displaying the 
			wgt.coordinates_prev = string.format("%02d",wgt.ctr) ..", ".. wgt.gpsPrevLAT..", " .. wgt.gpsPrevLON
			wgt.coordinates_current = string.format("%02d",wgt.ctr+1) ..", ".. wgt.gpsLAT..", " .. wgt.gpsLON		
											
			wgt.gpsPrevLAT = wgt.gpsLAT
			wgt.gpsPrevLON = wgt.gpsLON	
			
			--write logfile
			write_log(wgt)
		end 
	end			
  
  
end

function refresh(wgt)
	

	if (wgt == nil) then		
		print("GPS_Debug", "Widget not initialized - 2")	
		return
	end		
	
	get_data(wgt) 	

	--workaround to reset telemetry data via global session timer
	--reset via "long press enter" -> statistics -> "long press enter" exit menu under 10 seconds	
	if (SecondsToClock(getGlobalTimer()["session"]) == "00:00:10") then
		wgt.gpsDtH = 0
		wgt.gpsTotalDist = 0
		wgt.gpsLAT_H = 0
		wgt.gpsLON_H = 0	
	end 	
	
	-- display T16: 480*272px / 1/2 Zone size: 220x152 
	--headline
	if wgt.update == true then	
		lcd.setColor(CUSTOM_COLOR, lcd.RGB(0x9D, 0xD6, 0x00))
		lcd.drawFilledRectangle(wgt.zone.x + 0, wgt.zone.y + 0, wgt.zone.x + 215, 25, CUSTOM_COLOR)
		lcd.drawText(wgt.zone.x + 5,wgt.zone.y + 5,wgt.gpsFIX , LEFT + SMLSIZE + TEXT_COLOR)
	elseif wgt.update == false then
		lcd.setColor(CUSTOM_COLOR, lcd.RGB(0xe6, 0x32, 24))
		lcd.drawFilledRectangle(wgt.zone.x + 0, wgt.zone.y + 0, wgt.zone.x + 215, 25, CUSTOM_COLOR )
		lcd.drawText(wgt.zone.x + 5,wgt.zone.y + 5, "no GPS data available", LEFT + SMLSIZE + TEXT_COLOR)		
	end
	
	--line horz.
	lcd.drawLine(wgt.zone.x + 0, wgt.zone.y + 25, wgt.zone.x + 224, wgt.zone.y + 25, SOLID, LINE_COLOR)
	
	--satellites
	lcd.drawBitmap(sat_img, wgt.zone.x, wgt.zone.y + 30, 35)
	lcd.drawText(wgt.zone.x + 42,wgt.zone.y + 40, wgt.gpsSATS, LEFT + MIDSIZE + TEXT_COLOR)		
	--lcd.drawLine(wgt.zone.x + 74, wgt.zone.y + 25, wgt.zone.x + 74, wgt.zone.y + 85, SOLID, LINE_COLOR)	
	
	--distance to home
	lcd.drawBitmap(dis_img, wgt.zone.x + 80, wgt.zone.y + 30, 35)
	lcd.drawText(wgt.zone.x + 145 , wgt.zone.y + 30, wgt.gpsDtH, RIGHT + SMLSIZE + TEXT_COLOR)	
	lcd.drawText(wgt.zone.x + 145 , wgt.zone.y + 50, "km", RIGHT + SMLSIZE + TEXT_COLOR)	
	--lcd.drawLine(wgt.zone.x + 150, wgt.zone.y + 25, wgt.zone.x + 150, wgt.zone.y + 85, SOLID, LINE_COLOR)	
	
	--total total travel 
	lcd.drawBitmap(disT_img, wgt.zone.x + 155, wgt.zone.y + 30, 35)
	lcd.drawText(wgt.zone.x + 222, wgt.zone.y +30, wgt.gpsTotalDist, RIGHT + SMLSIZE + TEXT_COLOR)	
	lcd.drawText(wgt.zone.x + 222, wgt.zone.y +50, "km", RIGHT + SMLSIZE + TEXT_COLOR)	
	
	--line horz.
	lcd.drawLine(wgt.zone.x + 0, wgt.zone.y + 85, wgt.zone.x + 224, wgt.zone.y + 85, SOLID, LINE_COLOR)
	
	--home location
	lcd.drawBitmap(home_img, wgt.zone.x, wgt.zone.y + 95, 30)
	lcd.drawText(wgt.zone.x + 50, wgt.zone.y + 110, wgt.gpsLAT_H .. ", " .. wgt.gpsLON_H, LEFT + SMLSIZE + TEXT_COLOR)	
		
	--line horz.
	lcd.drawLine(wgt.zone.x + 0, wgt.zone.y + 145, wgt.zone.x + 224, wgt.zone.y + 145, SOLID, LINE_COLOR)
	
	--current and last location
	lcd.drawBitmap(drone_img, wgt.zone.x, wgt.zone.y + 150, 40)
	lcd.drawText(wgt.zone.x + 50,wgt.zone.y + 158, wgt.coordinates_prev,LEFT + SMLSIZE + TEXT_COLOR)
	lcd.drawText(wgt.zone.x + 50,wgt.zone.y + 180, wgt.coordinates_current,LEFT + SMLSIZE + TEXT_COLOR)
	
	 
end

return { name="GPS", options=options, create=create, update=update, refresh=refresh, background=background }
