#!/bin/bash

##-------------------------------------------------------------------------------
## INIT VARS
##-------------------------------------------------------------------------------
source ${HOME}/.api_keys.sh
LANG=en_us

URL_ONE_CALL=https\:\/\/api.openweathermap.org\/data\/2.5\/onecall\?lat=${LAT}\&lon=${LON}\&units=metric\&lang=${LANG}\&appid=${OWM_API_KEY}

URL_REV_GEOCODE=http\:\/\/api.openweathermap.org\/geo\/1.0\/reverse\?lat=${LAT}\&lon=${LON}\&limit=1\&appid=${OWM_API_KEY}

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

usage() {
        echo "Usage: $(basename $0) [-abch]" 2>&1
        echo "When called with no option it prints values" \
             " to STDOUT with defaults attributes"
        echo
        echo '   -a   shows alerts in the output'
        echo '   -b   shows b in the output'
        echo '   -c   shows c in the output'
        echo '   -h   shows this screen and exit'
        exit 1
}

##------------------------------------------------------------------------------
## Parsing flags
##------------------------------------------------------------------------------

# BOILER PLATE;
# code from getopt-parse.bash at /usr/share/doc/util-linux/examples/

TEMP=$(getopt -o 'ab:c::' --long 'alerts,b-long:,c-long::'\
        -n 'openweatherapi.sh' -- "$@")

if [ $? -ne 0 ]; then
	echo 'Terminating...' >&2
	exit 1
fi

# Note the quotes around "$TEMP": they are essential!
eval set -- "$TEMP"
unset TEMP

while true; do
	case "$1" in
		'-a'|'--alerts')
			aflag=1
			shift
			continue
		;;
		'-b'|'--b-long')
			echo "Option b, argument '$2'"
			shift 2
			continue
		;;
		'-c'|'--c-long')
			# c has an optional argument. As we are in quoted mode,
			# an empty parameter will be generated if its optional
			# argument is not found.
			case "$2" in
				'')
					echo 'Option c, no argument'
				;;
				*)
					echo "Option c, argument '$2'"
				;;
			esac
			shift 2
			continue
		;;
		'--')
			shift
			break
		;;
		*)
			echo 'Internal error!' >&2
			exit 1
		;;
	esac
done

echo 'Remaining arguments:'
for arg; do
	echo "--> '$arg'"
done

#-------------------------------------------------------------------------------

# Checking if no parameters were passed
# if [[ ${#} -eq 0 ]]; then
#    usage
# fi

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

CURRENT_WIND_DEG=$(echo $C_WEATHER | awk 'BEGIN{FS=","}{print $11}')

CW_DIR=$(wind_direction "$CURRENT_WIND_DEG")

CURRENT_WIND_SPEED=$(echo $C_WEATHER | awk 'BEGIN{FS=","}{print $4}')

CW_DESC=$(beaufort "$CURRENT_WIND_SPEED")

C_DATA="${C_DATA},${CW_DIR},${CW_DESC}"

##-------------------------------------------------------------------------------
## Hourly data
##-------------------------------------------------------------------------------

jq -r '.[0:6] [] | [.dt, .temp, .weather[].description, .wind_speed, .pop,
    .humidity, .uvi, .pressure, .clouds,
    if(.rain."1h" | length)>0 then .rain."1h" else 0 end ] | @csv' hourly_weather.json  \
        | awk 'BEGIN{FS=","; OFS=","} {
            gsub(/"/, "");
            $1=strftime("%H:%M", $1);
            $4=$4*3.6;
            $5=$5*100;
            print }' > table.csv


jq -r '.[] | [.dt, .temp, .weather[].description, .wind_speed, .pop,
    .humidity, .uvi, .pressure, .clouds,
    if(.rain."1h" | length)>0 then .rain."1h" else 0 end ] | @csv' hourly_weather.json  \
        | awk 'BEGIN{FS=","; OFS=",";
            print "Day,Temp,Desc,Wind,POP,Hum,UVI,Pres,Cloud,Rain"} {
                gsub(/"/, "");
                $1=strftime("%a-%d %H:%M", $1);
                $4=$4*3.6;
                $5=$5*100;
                print }' > table_complete.csv
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
            $16=$16*3.6;
            $18=$18*3.6;
            $24=$24*100;
        print}' > daily.csv

##-------------------------------------------------------------------------------
## Alerts
##-------------------------------------------------------------------------------

ALERT_NAME=$(cat onecall_response.json | jq 'try .alerts[].event ')
ALERT_DESC=$(cat onecall_response.json | jq 'try .alerts[].description')

jq -r 'try .alerts[] | flatten | @tsv' onecall_response.json | \
    awk 'BEGIN{FS= "\t"; OFS= "\t" ; ORS = "\r\n"} {
        gsub(/"/, "");
        $3=strftime("%b-%d %H:%M", $3);
        $4=strftime("%b-%d %H:%M", $4);
        gsub(/\\?"/, "");
        print}' > alerts.tsv


##-------------------------------------------------------------------------------
## Printing
##-------------------------------------------------------------------------------

# Current Weather
echo $C_DATA | awk 'BEGIN{FS=","; printf "OPEN WEATHER MAP API\n"}{
    printf "\nNow %s\n", $1;
    printf "%.f°C In %s, %s\n", $2, $16, $17;
    printf "Feels like %.0f°C with %s and %s\n", $13, $3, $20
    printf "Wind:%4.1fkm/h %3s\t Humidity: %2.0f%%\n", $4, $19, $6
    printf "Pressure: %4.0fhPa\t Dew Point: %.0f°C\n", $5, $7
    printf "UV: %.1f \t\t Visibility: %.1fkm\n\n", $9, $8
}'

# Hourly Table
printf "Next hours:\n"
column -t -s"," -N Time,Temp,Description,Wind,POP,Hum,UV,Pres,Cloud,Rain table.csv
printf "\n"

# Daily Table
printf "Next days:\n"
cut -d "," -f "1 8 9 14 16 21 23 24 25 26" daily.csv |\
    column -t -s"," -N Day,Min,Max,Hum,Wind,Desc,Cloud,POP,UVI,Rain
printf "\n"

# Alerts
if [[ ( -n $ALERT_NAME && $aflag -eq 1 ) ]]
    then
        awk 'BEGIN{FS="\t"; print "ALERTS"}{
            printf "Event: %s\n", $2
            printf "From: %s to %s\n", $3, $4
            printf "Description: %s\n", $5
        }' alerts.tsv
fi
