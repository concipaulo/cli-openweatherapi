#!/bin/bash

##-------------------------------------------------------------------------------
## INIT VARS
##-------------------------------------------------------------------------------
source ${HOME}/.api_keys.sh
LANG=en_us

URL_ONE_CALL=https\:\/\/api.openweathermap.org\/data\/2.5\/onecall\?lat=${LAT}\&lon=${LON}\&units=metric\&lang=${LANG}\&appid=${OWM_API_KEY}

URL_REV_GEOCODE=http\:\/\/api.openweathermap.org\/geo\/1.0\/reverse\?lat=${LAT}\&lon=${LON}\&limit=1\&appid=${OWM_API_KEY}

##-------------------------------------------------------------------------------
## Parsing flags
##-------------------------------------------------------------------------------

##-------------------------------------------------------------------------------
## API Call
##-------------------------------------------------------------------------------

# Calling the API
curl -s $URL_ONE_CALL > onecall_response.json

# Calling geocode api
curl -s $URL_REV_GEOCODE > geocode.json
GEOCODE_JSON_RESP=$(curl -s $URL_REV_GEOCODE)

##-------------------------------------------------------------------------------
## Extracting data, creating files
##-------------------------------------------------------------------------------

# dividing file into smaller parts, for faster reading
jq '.current' onecall_response.json > current_weather.json
jq ' .daily' onecall_response.json > daily_weather.json
jq ' .hourly' onecall_response.json > hourly_weather.json

NAME_CITY=$(echo $GEOCODE_JSON_RESP | jq -r '[ .[].name, .[].country,
        .[].state ] |  @csv' | awk 'BEGIN{FS=","}{ gsub(/"/, "" ); print}')

##-------------------------------------------------------------------------------
## Current weather
##-------------------------------------------------------------------------------

C_WEATHER=$(jq -r ' [.dt, .temp, .weather[].description, .wind_speed, .pressure, .humidity,
    .dew_point, .visibility, .uvi, .clouds, .wind_deg, .wind_gust, .feels_like,
    .sunrise, .sunset] | @csv' current_weather.json \
    | awk 'BEGIN{FS=","; OFS=","} {
        $1=strftime("%a %b %d at %T", $1);
        $4=$4*3.6;
        $8=$8/1000;
        $14=strftime("%H:%M", $14);
        $15=strftime("%H:%M", $15);
        gsub(/"/, "", $3);
        print }')

C_DATA="${C_WEATHER},${NAME_CITY}"

##-------------------------------------------------------------------------------
## Functions
##-------------------------------------------------------------------------------

wind_direction(){
    W_DIR=$(awk -v wind="$1" 'BEGIN{FS = ","} {
        if(wind>$2 && wind<=$3) print $1}' wind_direction_metereological.csv)
    echo $W_DIR
}

beaufort(){
    W_DESC=$(awk -v speed="$1" 'BEGIN{FS=","}{
        if(speed<$3 && speed>=$2) print $1}' beaufort_scale.csv)
    echo $W_DESC
}

##-------------------------------------------------------------------------------

CURRENT_WIND_DEG=$(echo $C_WEATHER | awk 'BEGIN{FS=","}{print $11}')

CW_DIR=$(wind_direction "$CURRENT_WIND_DEG")

CURRENT_WIND_SPEED=$(echo $C_WEATHER | awk 'BEGIN{FS=","}{print $4}')

CW_DESC=$(beaufort "$CURRENT_WIND_SPEED")

C_DATA="${C_DATA},${CW_DIR},${CW_DESC}"

##-------------------------------------------------------------------------------
## Hourly data
##-------------------------------------------------------------------------------

jq -r '.[0:6] [] | [.dt, .temp, .weather[].description, .wind_speed, .pop,
    .humidity, .uvi, .pressure] | @csv' hourly_weather.json  \
        | awk 'BEGIN{FS=","; OFS=","} {
            $1=strftime("%H:%M", $1);
            gsub(/"/, "");
            print }' > table.csv

##-------------------------------------------------------------------------------
## Daily data
##-------------------------------------------------------------------------------

jq '.[] | [.dt, .sunrise, .sunset, .moonrise, .moonset, .moon_phase, .temp.day,
    .temp.min, .temp.max, .temp.night, .temp.eve, .temp.morn, .pressure,
    .humidity, .dew_point, .wind_speed, .wind_deg, .wind_gust, .weather[].id,
    .weather[].main, .weather[].description, .weather[].icon, .clouds, .pop,
    .uvi, if(.rain | length)>0 then .rain else 0 end ] | @csv ' daily_weather.json \
        | awk 'BEGIN{FS = ","; OFS = ","}{
            gsub(/\\?"/, "");
            $1=strftime("%a-%b-%d", $1);
            $2=strftime("%H:%M", $2);
            $3=strftime("%H:%M", $3);
            $4=strftime("%H:%M", $4);
            $5=strftime("%H:%M", $5);
        print}' > daily.csv

##-------------------------------------------------------------------------------
## Alerts
##-------------------------------------------------------------------------------

ALERT_NAME=$(cat onecall_response.json | jq 'try .alerts[].event ')
ALERT_DESC=$(cat onecall_response.json | jq 'try .alerts[].description')

##-------------------------------------------------------------------------------
## Printing
##-------------------------------------------------------------------------------

# Current Weather
echo $C_DATA | awk 'BEGIN{FS=","; printf "OPEN WEATHER MAP API\n"}{
    printf "\nNow %s\n", $1;
    printf "%.f°C In %s, %s\n", $2, $16, $17;
    printf "Feels like %.0f°C with %s and %s\n", $13, $3, $20
    printf "Wind: %.1fkm/h %s\t Humidity: %.0f%%\n", $4, $19, $6
    printf "Pressure: %4.0fhPa\t Dew Point: %.0f°C\n", $5, $7
    printf "UV: %.1f \t\t Visibility: %.1fkm\n\n", $9, $8
}'

# Hourly Table
column -t -s"," -N Time,Temp,Description,Wind,POP,Hum,UV,Pres table.csv
printf "\n"

# Daily Table
cut -d "," -f "1 8 9 14 16 21 23 24 25 26" daily.csv | column -t -s","
printf "\n"

# Alerts
if [[ -n $ALERT_NAME ]]
    then
        printf "ALERTS:\n"
        printf "Event: %s\n" "$ALERT_NAME"
        printf "Description: %s\n" "$ALERT_DESC"
fi
