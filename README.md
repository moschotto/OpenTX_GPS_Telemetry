# OpenTX/EdgeTX GPS Widget / telemetry screen

## GPS LUA TELEMETRY scripts v2.5

Copyright (C) by mosch   
License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html       
GITHUB: https://github.com/moschotto?tab=repositories 

## make sure that your radio is a least on OpenTX 2.3.x / EdgeTX 2.6.0

### :exclamation: Even if your radio is not listed down below, check the resolution of your radio screen and use the scripts below (don't care about the naming)
=> e.g. the x7 / x9 lite scripts are working on the Jumper T-Pro as well (same display resolution)

NOTE: i'm not using EdgeTX - tested in simulator only


### Radios with 480x272 pixel displays (e.g. Jumper T16)
- /T16/GPS
- /T16/GPS Stats T16.lua

### Radios with 212x64 pixel displays (e.g. x9d/x9+/x9E)
- /x9/GPSx9.lua
- /x9/GPS Stats X9.lua

### Radios with 128x96 pixel displays (e.g. TBS Tango 2)
- /TBS_Tango/GPSxT.lua
- /TBS_Tango/GPSviewerT.lua

### Radios with 128x64 pixel displays (e.g. x7 / x9 lite / Jumper T-lite)

- /x7_x9lite/GPSx9L.lua
- /x7_x9lite/GPS Stats X9L.lua

## Description:
How to find your model in case of a crash, power loss etc? Right, check the last 
GPS coordinates and type it into to your mobile phone...

![Alt text](https://github.com/moschotto/Taranis_GPS_Telemetry/blob/main/media/description.png)

- Shows and logs GPS related information. logfile will be generated in
/LOGS/GPSpositions.txt

- GPS logfile can be viewed with the GPS stats XXX.lua" on the radio itself

- in case that the telemetry stops, the last coordinates will remain on the screen

- distance from your home position - how far you need to walk ;)

## Usage:

Once you have a good and valid GPS fix (>5 satellites) you need to set the home position manualy.

For non color screen radios, just "long press enter" and exit the menu without selecting anything.

![](https://github.com/moschotto/OpenTX_GPS_Telemetry/blob/main/media/x9l_reset.gif)


For color screen radios via "long press enter" -> statistics -> "long press enter" to reset statistics and exit menu in under 10 seconds	

![](https://github.com/moschotto/OpenTX_GPS_Telemetry/blob/main/media/T16_reset.gif)


## Installation for Taranis models:
1. copy GPSxxx.lua to /SCRIPTS/TELEMETRY
2. copy GPS Stats XXX.lua to /SCRIPTS/TOOLS
3. copy the BMP folder to /SCRIPTS/TELEMETRY/BMP
4. :exclamation: make sure that the /LOGS/ folder exists. If not, create it
5. Setup a "screen (DIsplay 13/13)" and select GPSxxx.lua
6. Make sure GPS, speed, alt sensors have been discovered within the telemetry menu/screen of opentx/edgetx

## Installation for color screen models i.e Jumper/HOROUS/Radiomaster:

1. copy the GPS folder (inculding subfolders) to /WIDGETS/GPS
2. copy GPS stats T16.lua to /SCRIPTS/TOOLS
3. :exclamation: make sure that the /LOGS/ folder exists. If not, create it
4. Setup "1/2" widget screen and select "GPS"
5. Make sure GPS, speed, alt sensors have been discovered within the telemetry menu/screen of opentx/edgetx


#########################


### x7 / x9 lite Screens:

![Alt text](https://github.com/moschotto/Taranis_GPS_Telemetry/blob/main/media/x9L_GPS_screen.PNG)

![Alt text](https://github.com/moschotto/Taranis_GPS_Telemetry/blob/main/media/x9L_GPSstatsviewer.PNG)

### x9d/x9+/x9E Screens:

![Alt text](https://github.com/moschotto/Taranis_GPS_Telemetry/blob/main/media/x9_GPS_screen.PNG)

![Alt text](https://github.com/moschotto/Taranis_GPS_Telemetry/blob/main/media/x9_GPSstatsviewer.PNG)

### JUMPER T16 / HOROUS etc WIDGET screen:
![Alt text](https://github.com/moschotto/Taranis_GPS_Telemetry/blob/main/media/T16_GPS_screen.png)

![Alt text](https://github.com/moschotto/Taranis_GPS_Telemetry/blob/main/media/T16_GPSstatsviewer.png)


### Demo Video

<a href="http://www.youtube.com/watch?feature=player_embedded&v=9Jt2rRiSq0U" target="_blank"><img src="http://img.youtube.com/vi/9Jt2rRiSq0U/0.jpg" 
alt="IMAGE ALT TEXT HERE" width="240" height="180" border="10" /></a>


[![Hits](https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Fmoschotto%2FOpenTX_GPS_Telemetry&count_bg=%2379C83D&title_bg=%23555555&icon=&icon_color=%23E7E7E7&title=hits&edge_flat=false)](https://hits.seeyoufarm.com)

