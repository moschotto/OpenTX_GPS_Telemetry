--[[#############################################################################
GPS Telemetry Widget for Jumper TX16 etc (480x272 displays)
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

Install:
- copy the GPS folder (inculding subfolders) to /WIDGETS/GPS
- Setup 1/2 widget screen and select "GPS"

################################################################################]]


log_filename = "/LOGS/GPSpositions.txt"
local background_img
local sat_img 
local dis_img 
local disT_img 
local home_img  
local drone_img
local newtext_color = BLACK
local newline_color = WHITE


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

			io.write(file, wgt.coordinates_current ..",".. time_power_on ..", "..  wgt.gpsSATS..", ".. wgt.gpsALT ..", ".. wgt.gpsSpeed, "\r\n")					
			io.close(file)			

			if wgt.ctr >= 99 then
				wgt.ctr = 0				
				--clear log and add headline
				file = io.open(log_filename, "w") 
					io.write(file, "Number,LAT,LON,radio_time,satellites,GPSalt,GPSspeed", "\r\n")		
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
	
	--[	####################################################################
	--[	ETX and OTX compatible draw text with color
	--[	####################################################################
	local function lcl_drawText(x, y, txt, flags, color)
		lcd.setColor(CUSTOM_COLOR, color)
		lcd.drawText(x, y, txt, flags + CUSTOM_COLOR)
	end
	
	--[	####################################################################
	--[	ETX and OTX compatible draw filled rect with color
	--[	####################################################################
	local function lcl_drawFilledRectangle(x1, y1, x2, y2, color)
		lcd.setColor(CUSTOM_COLOR, color)
		lcd.drawFilledRectangle(x1, y1, x2, y2, CUSTOM_COLOR)			
	end	

	--[	####################################################################
	--[	ETX and OTX compatible draw line with color
	--[	####################################################################
	local function lcl_drawLine(x1, y1, x2, y2, pattern, flags, color)
		lcd.setColor(CUSTOM_COLOR, color)
		lcd.drawLine(x1, y1, x2, y2, pattern, flags + CUSTOM_COLOR)
	end
	


--############################################################################
local options = {
  { "TextColor", COLOR, BLACK },
  { "LineColor", COLOR, WHITE },
  { "Debug", BOOL, 0 }
}

local function create(zone, options)
	local wgt = { 
	zone=zone, 
	options=options, 
	counter=0,		
	gpsId=0,
	gpssatId=0,	
	gpsspeedId=0,	
	gpsaltId=0,	
	gpsLAT = 0,
	gpsLON = 0,
	gpsLAT_H = 0,
	gpsLON_H = 0,
	gpsPrevLAT = 0,
	gpsPrevLON = 0,
	gpsSATS = 0,
	gpsSpeed = 0,
	gpsALT = 0,
	gpsFIX = 0,
	gpsDtH = 0,
	gpsTotalDist = 0,
	log_write_wait_time = 10,
	old_time_write = 0,
	update = true,
	reset_home = false,
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
	background_img = Bitmap.open("/WIDGETS/GPS/BMP/background.png")
	
		
	return wgt
end

local function update(wgt, options)

	if (wgt == nil) then		
		print("GPS_Debug", "Widget not initialized - 1")	
		return
	end
	
	wgt.options = options   

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
	
	--get IDs GPS Speed and GPS altitude
	wgt.gpsspeedId = getTelemetryId("GSpd") --GPS ground speed m/s
	wgt.gpsaltId = getTelemetryId("Alt") --GPS altitude m
	
	--if "ALT" can't be read, try to read "GAlt"
	if (wgt.gpsaltId == -1) then gpsaltId = getTelemetryId("GAlt") end	
	
	--if Stats can't be read, try to read Tmp2 (number of satellites SBUS/FRSKY)
	if (wgt.gpssatId == -1) then wgt.gpssatId = getTelemetryId("Tmp2") end	
		  
	  
	--####################################################################
	--get Latitude, Longitude, Speed and Altitude
	--####################################################################		
	wgt.gpsLatLon = getValue(wgt.gpsId)
		
	if (type(wgt.gpsLatLon) == "table") then 			
		wgt.gpsLAT = rnd(wgt.gpsLatLon["lat"],6)
		wgt.gpsLON = rnd(wgt.gpsLatLon["lon"],6)	
		wgt.gpsSpeed = rnd(getValue(wgt.gpsspeedId) * 1.852,1)
		wgt.gpsALT = rnd(getValue(wgt.gpsaltId),0)
		
					
		--set home postion only if more than 5 sats available
		if (tonumber(wgt.gpsSATS) > 5) and (wgt.reset_home == true) then
			wgt.gpsLAT_H = rnd(wgt.gpsLatLon["lat"],6)
			wgt.gpsLON_H = rnd(wgt.gpsLatLon["lon"],6)	
			wgt.reset_home = false			
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
		-- smartport Example 1014: -> 1= GPS fix | 0=lowest accuracy | 14=14 active satellites
		--[	Sats / Tmp2 : GPS lock status, accuracy, home reset trigger, and number of satellites. 
		--[ 	Number is sent as ABCD detailed below. ABCD = 1014
		--[	A : 1 = GPS fix, 2 = GPS home fix, 4 = home reset (numbers are additive)
		--[	B : GPS accuracy based on HDOP (0 = lowest to 9 = highest accuracy)
		--[	C : number of satellites locked (first digit)
		--[ 	D : number of satellites locked (second digit)
		--[ 	for example: "1014"  C = 1 & D = 4 => 14 satellites
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
	
		if (wgt.gpsLAT ~= wgt.gpsPrevLAT) and (wgt.gpsLON ~=  wgt.gpsPrevLON) then		
		--if (string.len(gpsLAT) > 4) and  (string.len(gpsLON) > 4) and (tonumber(gpsSATS) > 5) then  
					
			--distance to home
			if (wgt.gpsLAT_H ~= 0) and  (wgt.gpsLON_H ~= 0) then
			
				wgt.gpsDtH = rnd(calc_Distance(wgt.gpsLAT, wgt.gpsLON, wgt.gpsLAT_H, wgt.gpsLON_H),2)			
				wgt.gpsDtH = string.format("%.2f",wgt.gpsDtH)		
				
				--total distance traveled					
				if (wgt.gpsPrevLAT ~= 0) and  (wgt.gpsPrevLON ~= 0) then	
					
					wgt.gpsTotalDist =  rnd(tonumber(wgt.gpsTotalDist) + calc_Distance(wgt.gpsLAT,wgt.gpsLON,wgt.gpsPrevLAT,wgt.gpsPrevLON),2)			
					wgt.gpsTotalDist = string.format("%.2f",wgt.gpsTotalDist)					
				end
				
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

--function refresh(wgt)
function refresh(wgt, event, touchState)
	
	if (wgt == nil) then		
		print("GPS_Debug", "Widget not initialized - 2")	
		return
	end		

	-- set the colours
	newtext_color = wgt.options.TextColor
	newline_color = wgt.options.LineColor	
	
	
	get_data(wgt) 	

	--workaround to reset telemetry data via global session timer
	--reset via "long press enter" -> statistics -> "long press enter" exit menu under 10 seconds	
	if (SecondsToClock(getGlobalTimer()["session"]) == "00:00:10") then
		wgt.gpsDtH = 0
		wgt.gpsTotalDist = 0
		wgt.gpsLAT_H = 0
		wgt.gpsLON_H = 0	
		wgt.reset_home = true
	end 	
	
	if wgt.options.Debug == 0 then
	
		-- display T16: 480*272px / 1/2 Zone size: 220x152 
		--headline
		if wgt.update == true then					
			lcl_drawFilledRectangle(wgt.zone.x + 0, wgt.zone.y + 0, 225, 25, lcd.RGB(0x9D, 0xD6, 0x00))						
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 5,wgt.gpsFIX , LEFT + SMLSIZE ,  newtext_color)
		elseif wgt.update == false then		
			lcl_drawFilledRectangle(wgt.zone.x + 0, wgt.zone.y + 0,  225, 25, lcd.RGB(0xE6, 0x32, 24))		
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 5, "no GPS data available", LEFT + SMLSIZE ,  newtext_color)		
		end
				
		--satellites
		lcd.drawBitmap(sat_img, wgt.zone.x, wgt.zone.y + 30, 35)
		lcl_drawText(wgt.zone.x + 42,wgt.zone.y + 40, wgt.gpsSATS, LEFT + MIDSIZE ,  newtext_color)		
			
		--distance to home
		lcd.drawBitmap(dis_img, wgt.zone.x + 80, wgt.zone.y + 30, 35)
		lcl_drawText(wgt.zone.x + 145 , wgt.zone.y + 30, wgt.gpsDtH, RIGHT + SMLSIZE ,  newtext_color)	
		lcl_drawText(wgt.zone.x + 145 , wgt.zone.y + 50, "km", RIGHT + SMLSIZE ,  newtext_color)	
			
		--total total travel 
		lcd.drawBitmap(disT_img, wgt.zone.x + 155, wgt.zone.y + 30, 35)
		lcl_drawText(wgt.zone.x + 222, wgt.zone.y +30, wgt.gpsTotalDist, RIGHT + SMLSIZE ,  newtext_color)	
		lcl_drawText(wgt.zone.x + 222, wgt.zone.y +50, "km", RIGHT + SMLSIZE ,  newtext_color)	
		
		--line horz.
		lcl_drawLine(wgt.zone.x + 0, wgt.zone.y + 85, wgt.zone.x + 224, wgt.zone.y + 85, SOLID, 0, newline_color)

		
		--home location
		lcd.drawBitmap(home_img, wgt.zone.x, wgt.zone.y + 95, 30)
		
		if (wgt.gpsLAT_H ~= 0) and  (wgt.gpsLON_H ~= 0) then
			lcl_drawText(wgt.zone.x + 50, wgt.zone.y + 110, wgt.gpsLAT_H .. ", " .. wgt.gpsLON_H, LEFT + SMLSIZE,  newtext_color)	
		else
			lcl_drawText(wgt.zone.x + 50, wgt.zone.y + 90, "home not set" , LEFT + SMLSIZE + BLINK,  newtext_color)	
			lcl_drawText(wgt.zone.x + 50, wgt.zone.y + 105, "reset STATS once a", LEFT + SMLSIZE ,  newtext_color)	
			lcl_drawText(wgt.zone.x + 50, wgt.zone.y + 120, "GPS fix is obtained", LEFT + SMLSIZE ,  newtext_color)	
		end
			
		--line horz.
		lcl_drawLine(wgt.zone.x + 0, wgt.zone.y + 145, wgt.zone.x + 224, wgt.zone.y + 145, SOLID, 0, newline_color)
		
		--drone location (current and previous)
		lcd.drawBitmap(drone_img, wgt.zone.x, wgt.zone.y + 150, 40)
		lcl_drawText(wgt.zone.x + 50,wgt.zone.y + 158, wgt.coordinates_prev,LEFT + SMLSIZE ,  newtext_color)
		lcl_drawText(wgt.zone.x + 50,wgt.zone.y + 180, wgt.coordinates_current,LEFT + SMLSIZE ,  newtext_color)
			
	
	elseif wgt.options.Debug == 1 then
	
		if (type(wgt.gpsLatLon) == "table") then  
									
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y,"Debug view:", LEFT + SMLSIZE ,  newtext_color)
			
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 15,"Lat: " .. rnd(wgt.gpsLatLon["lat"],6) , LEFT + SMLSIZE ,  newtext_color)			
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 30,"Lon: " .. rnd(wgt.gpsLatLon["lon"],6) , LEFT + SMLSIZE ,  newtext_color)
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 45,"P lat: " .. rnd(wgt.gpsLatLon["pilot-lat"],6) , LEFT + SMLSIZE ,  newtext_color)
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 60,"P lon: " .. rnd(wgt.gpsLatLon["pilot-lon"],6) , LEFT + SMLSIZE ,  newtext_color)
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 75,"Home lat: " .. wgt.gpsLAT_H , LEFT + SMLSIZE ,  newtext_color)
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 90,"Home lon: " .. wgt.gpsLON_H , LEFT + SMLSIZE ,  newtext_color)
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 105,"Satellites: " .. wgt.gpsSATS , LEFT + SMLSIZE ,  newtext_color)			
			
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 120,"Dist home: " .. wgt.gpsDtH , LEFT + SMLSIZE ,  newtext_color)
			lcl_drawText(wgt.zone.x + 120,wgt.zone.y + 120,"ALT: " .. wgt.gpsALT , LEFT + SMLSIZE ,  newtext_color)			
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 135,"Dist travel: " .. wgt.gpsTotalDist , LEFT + SMLSIZE ,  newtext_color)			
			lcl_drawText(wgt.zone.x + 120,wgt.zone.y + 135,"SPD: " .. wgt.gpsSpeed , LEFT + SMLSIZE ,  newtext_color)		
			
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 150,"GPS ID: " .. wgt.gpsId, LEFT + SMLSIZE ,  newtext_color)
			lcl_drawText(wgt.zone.x + 120,wgt.zone.y + 150,"SAT ID: " .. wgt.gpssatId, LEFT + SMLSIZE ,  newtext_color)			
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 165,"SPD ID: " .. wgt.gpsspeedId , LEFT + SMLSIZE ,  newtext_color)
			lcl_drawText(wgt.zone.x + 120,wgt.zone.y + 165,"ALT ID: " .. wgt.gpsaltId , LEFT + SMLSIZE ,  newtext_color)			
			
		else			
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 60,"No GPS data available" , LEFT + SMLSIZE ,  newtext_color)
			lcl_drawText(wgt.zone.x + 5,wgt.zone.y + 75,"Please check the sensors" , LEFT + SMLSIZE ,  newtext_color)
		end
		
	end
	 
end

return { name="GPS", options=options, create=create, update=update, refresh=refresh, background=background }
