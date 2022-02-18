#!/bin/bash

##-------------------------------------------------------------------------------
## INIT VARS
##-------------------------------------------------------------------------------

source ${HOME}/.api_keys.sh
LANG=pt_br

URL_ONE_CALL=https\:\/\/api.openweathermap.org\/data\/2.5\/onecall\?lat=${LAT}\&lon=${LON}\&units=metric\&lang=${LANG}\&appid=${OWM_API_KEY}

URL_REV_GEOCODE=http\:\/\/api.openweathermap.org\/geo\/1.0\/reverse\?lat=${LAT}\&lon=${LON}\&limit=1\&appid=${OWM_API_KEY}

##-------------------------------------------------------------------------------
## API CALL
##-------------------------------------------------------------------------------

# Calling the API
curl -s $URL_ONE_CALL > onecall_response.json

# Calling geocode api
curl -s $URL_REV_GEOCODE > geocode.json
# GEOCODE_JSON_RESP=$(curl $URL_REV_GEOCODE)

##-------------------------------------------------------------------------------
## Extracting data, creating files
##-------------------------------------------------------------------------------

# dividing file into smaller parts, for faster reading
jq '.current' onecall_response.json > current_weather.json
jq ' .daily' onecall_response.json > daily_weather.json
jq ' .hourly' onecall_response.json > hourly_weather.json

##-------------------------------------------------------------------------------
## Extracting data, creating files
##-------------------------------------------------------------------------------

C_DT=$(cat current_weather.json | jq '.dt' | awk '{print "@" $0}')
CURRENT_TIME=$(date -d $C_DT +"%a %b %d at %T")
CURRENT_TEMP=$(cat current_weather.json | jq '.temp' | awk '{print int($1)}')
CURRENT_W_DESC=$(cat current_weather.json | jq '.weather[].description')
CURRENT_WIND=$(cat current_weather.json | jq '.wind_speed')
CURRENT_PRESSURE=$(cat current_weather.json | jq '.pressure')
CURRENT_HUMIDITY=$(cat current_weather.json | jq '.humidity')
CURRENT_DEW=$(cat current_weather.json | jq '.dew_point')
CURRENT_VIS=$(cat current_weather.json | jq '.visibility')
CURRENT_UV=$(cat current_weather.json | jq '.uvi')

##-------------------------------------------------------------------------------
## Hourly data
##-------------------------------------------------------------------------------

ONE_HOUR_TIME=$(cat hourly_weather.json | jq '.[0].dt')
TWO_HOUR_TIME=$(cat hourly_weather.json | jq '.[1].dt')
THREE_HOUR_TIME=$(cat hourly_weather.json | jq '.[2].dt')
FOUR_HOUR_TIME=$(cat hourly_weather.json | jq '.[3].dt')
FIVE_HOUR_TIME=$(cat hourly_weather.json | jq '.[4].dt')
SIX_HOUR_TIME=$(cat hourly_weather.json | jq '.[5].dt')

HOURLY_TIMES=$(jq '.[0:5] | .[].dt' hourly_weather.json)
HOURLY_TEMP=$(jq '.[0:5] | .[].temp' hourly_weather.json)
HOURLY_DESC=$(jq '.[0:5] | .[].weather[].description' hourly_weather.json)
HOURLY_WIND=$(jq '.[0:5] | .[].wind_speed' hourly_weather.json)
HOURLY_POP=$(jq '.[0:5] | .[].pop' hourly_weather.json)
HOURLY_HUM=$(jq '.[0:5] | .[].humidity' hourly_weather.json)
HOURLY_UV=$(jq '.[0:5] | .[].uvi' hourly_weather.json)
HOURLY_PRESS=$(jq '.[0:5] | .[].pressure' hourly_weather.json)


jq -r '.[0:9] [] | [.dt, .temp, .weather[].description, .wind_speed, .pop, .humidity, .uvi, .pressure] | @csv' hourly_weather.json |\
    awk 'BEGIN{FS=","; OFS=","}\
    {$1=strftime("%H:%M", $1);\
        print }' > table.csv
##-------------------------------------------------------------------------------
## Daily data
##-------------------------------------------------------------------------------

TOMOROW_WEATHER=$(cat daily_weather.json | jq '.[1]')

T_TIME=$(echo $TOMOROW_WEATHER | jq '.dt' | awk '{print "@" $0}')
T_SUNRISE=$(echo $TOMOROW_WEATHER | jq '.sunrise' | awk '{print "@" $0}')
T_SUNSET=$(echo $TOMOROW_WEATHER | jq '.sunset' | awk '{print "@" $0}')
T_PRESS=$(echo $TOMOROW_WEATHER | jq '.pressure')
T_DEW=$(echo $TOMOROW_WEATHER | jq '.dew_point')
T_WIND=$(echo $TOMOROW_WEATHER | jq '.wind_speed')
T_WIND_DEG=$(echo $TOMOROW_WEATHER | jq '.wind_deg')
T_POP=$(echo $TOMOROW_WEATHER | jq '.pop')
T_RAIN=$(echo $TOMOROW_WEATHER | jq 'if(.rain | length)>0 then .rain else 0 end')
T_UV=$(echo $TOMOROW_WEATHER | jq '.uvi')
T_CLOUDS=$(echo $TOMOROW_WEATHER | jq '.clouds')
T_HUM=$(echo $TOMOROW_WEATHER | jq '.humidity')

T_TEMP_DAY=$(echo $TOMOROW_WEATHER | jq '.temp.day' | awk '{print int($1)}')
T_TEMP_NIG=$(echo $TOMOROW_WEATHER | jq '.temp.night' | awk '{print int($1)}')
T_TEMP_MAX=$(echo $TOMOROW_WEATHER | jq '.temp.max' | awk '{print int($1)}')
T_TEMP_MIN=$(echo $TOMOROW_WEATHER | jq '.temp.min' | awk '{print int($1)}')

T_DESC=$(echo $TOMOROW_WEATHER | jq '.weather[].description')


##-------------------------------------------------------------------------------
## Alerts
##-------------------------------------------------------------------------------

ALERT_NAME=$(cat onecall_response.json | jq '.alerts[].event')
ALERT_DESC=$(cat onecall_response.json | jq '.alerts[].description')

##-------------------------------------------------------------------------------
## Printing
##-------------------------------------------------------------------------------

CITY_NAME=$(cat geocode.json | jq '.[].name')
COUNTRY=$(cat geocode.json | jq '.[].country')
C_WIND_KMH=$(echo $CURRENT_WIND*3.6 | bc)
T_WIND_KMH=$(echo $T_WIND*3.6 | bc)
T_POP_PCT=$(echo $T_POP*100 | bc | awk '{print int($1)}')

# Right now
printf "\n"
printf "OPEN WEATHER MAP API\n"
printf "Now %s in %s, %s\n" "$CURRENT_TIME" $CITY_NAME $COUNTRY
printf "Temp: %d°C - %s\n" $CURRENT_TEMP "$CURRENT_W_DESC"
printf "Wind: %.2fm/s(%.2fkm/h)\n" $CURRENT_WIND $C_WIND_KMH
printf "Pressure: %dhPa\n" $CURRENT_PRESSURE
printf "Humidity: %.1f%%\n" $CURRENT_HUMIDITY
printf "Dew Point: %.1f°C\n" $CURRENT_DEW
printf "Visibility: %dm\n" $CURRENT_VIS
printf "UV: %.2f\n" $CURRENT_UV
printf "\n"

# Hourly table

cat table.csv | column -t -s"," -N Time,Temp,Description,Wind,POP,Hum,UV,Pres
printf "\n"

#Tomorrow data
printf "Tomorrow\n"
printf "Sunrise at %s and Sunset at %s\n" $(date -d $T_SUNRISE +"%T") $(date -d $T_SUNSET +"%T")
printf "Temp High: %d°C; Temp Low: %d°C\n" $T_TEMP_MAX $T_TEMP_MIN
printf "Temp Day: %d°C; Temp Night: %d°C\n" $T_TEMP_DAY $T_TEMP_NIG
printf "Description: %s\n" "$T_DESC"
printf "Rain Acul.: %.2fmm(%d%%)\n" $T_RAIN $T_POP_PCT
printf "Wind: %.2fm/s(%.2fkm/h)\n" $T_WIND $T_WIND_KMH
printf "Pressure: %dhPa\n" $T_PRESS
printf "Humidity: %.1f%%\n" $T_HUM
printf "Dew Point: %.1f°C\n" $T_DEW
printf "UV: %.2f\n" $T_UV
printf "\n"

# Alerts
printf "ALERTS:\n"
printf "Event: %s\n" "$ALERT_NAME"
printf "Description: %s\n" "$ALERT_DESC"
