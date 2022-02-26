#!/bin/bash

##-------------------------------------------------------------------------------
## INIT VARS
##-------------------------------------------------------------------------------
source ${HOME}/.api_keys.sh
LANG=en_us

#TODO break this loooong lines
URL_ONE_CALL=https\:\/\/api.openweathermap.org\/data\/2.5\/onecall\?lat=${LAT}\&lon=${LON}\&units=metric\&lang=${LANG}\&appid=${OWM_API_KEY}

URL_REV_GEOCODE=http\:\/\/api.openweathermap.org\/geo\/1.0\/reverse\?lat=${LAT}\&lon=${LON}\&limit=1\&appid=${OWM_API_KEY}

##-------------------------------------------------------------------------------
## Functions
##-------------------------------------------------------------------------------

# this function accepts inputs from stdin and positional args
wind_direction(){

    local input=""

    if [[ -p /dev/stdin ]]; then
        input="$(cat -)"
    else
        input="${@}"
    fi

    if [[ -z "${input}" ]]; then
        return 1
    fi

    W_DIR=$(awk -v wind="$input" 'BEGIN{FS = ","} {
        if(wind>$2 && wind<=$3) print $1}' 20-metereological_wind_direction)
    echo $W_DIR

}

# this function accepts inputs from stdin and positional args
beaufort(){

    local input=""

    if [[ -p /dev/stdin ]]; then
        input="$(cat -)"
    else
        input="${@}"
    fi

    if [[ -z "${input}" ]]; then
        return 1
    fi

    W_DESC=$(awk -v speed="$input" 'BEGIN{FS=","}{
        if(speed<$3 && speed>=$2) print $1}' 30-beaufort_scale)
    echo $W_DESC
}

usage() {
        echo "Usage: $(basename $0) [-abch]" 2>&1
        echo "When called with no option it prints values" \
             " to STDOUT with defaults attributes"
        echo
        echo '   -a                 shows alerts in the output'
        echo '   -d[N] | --days     shows N days in the output'
        echo '   -h[N] | --hours    shows N hours in the output'
        echo '   --help             shows this screen and exit'
        exit 1
}

##------------------------------------------------------------------------------
## Parsing flags
##------------------------------------------------------------------------------

# BOILER PLATE;
# code from getopt-parse.bash at /usr/share/doc/util-linux/examples/
# string after -o are the single letter arguments, --long defines the multi
# letters options -n is the name of the program to append the error and
# "$@" is the string of args, MUST be enclosed by double quotes
TEMP=$(getopt -o 'ad:h:c::' --long 'alerts,days:,help,hours:,c-long::'\
        -n 'openweatherapi.sh' -- "$@")

# If last command wasn't sucessful exit
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
		'-d'|'--days')
            DAYS_NBR=$2
			shift 2
			continue
		;;
        # help will exit on function usage with flag 1
		'--help')
            usage
			shift
			continue
		;;
		'-h'|'--hours')
            HOURS_NBR=$2
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

# Arguments that were unable to be parsed
# echo 'Unknown arguments:'
# for arg; do
#     echo "--> '$arg'"
# done

#-------------------------------------------------------------------------------
# DEFAULTS
#-------------------------------------------------------------------------------

if ( [ -z $DAYS_NBR ] || [ $DAYS_NBR -gt 8 ] ) then
    DAYS_NBR=8
fi

if ( [ -z $HOURS_NBR ] || [ $HOURS_NBR -gt 48 ] ) then
    HOURS_NBR=6
fi
#
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
GEOCODE_JSON_RESP=$(curl -s $URL_REV_GEOCODE)

##-------------------------------------------------------------------------------
## Extracting data, creating files
##-------------------------------------------------------------------------------

# dividing file into smaller parts, for faster reading
jq '.current' onecall_response.json > current_weather.json
jq ' .daily' onecall_response.json > daily_weather.json
jq ' .hourly' onecall_response.json > hourly_weather.json
jq ' .minutely' onecall_response.json > minutely_weather.json

NAME_CITY=$(echo $GEOCODE_JSON_RESP | jq -r '[ .[].name, .[].country,
        .[].state ] |  @csv' | awk 'BEGIN{FS=","}{ gsub(/"/, "" ); print}')

##-------------------------------------------------------------------------------
## Current data
##-------------------------------------------------------------------------------

C_WEATHER=$(jq -r ' [.dt,
            .temp,
            .weather[].description,
            .wind_speed,
            .pressure,
            .humidity,
            .dew_point,
            .visibility,
            .uvi,
            .clouds,
            .wind_deg,
            .wind_gust,
            .feels_like,
            .sunrise,
            .sunset] | @csv' current_weather.json \
                | awk 'BEGIN{FS=","; OFS=","} {
                    $1=strftime("%a %b %d at %T", $1);
                    $4=$4*3.6;
                    $8=$8/1000;
                    $14=strftime("%H:%M", $14);
                    $15=strftime("%H:%M", $15);
                    gsub(/"/, "", $3);
                    print
                }'
)

C_DATA="${C_WEATHER},${NAME_CITY}"

##-------------------------------------------------------------------------------

CW_DIR=$(echo $C_WEATHER | awk 'BEGIN{FS=","}{print $11}' | wind_direction )

CW_DESC=$(echo $C_WEATHER | awk 'BEGIN{FS=","}{print $4}' | beaufort )

C_DATA="${C_DATA},${CW_DIR},${CW_DESC}"

##-------------------------------------------------------------------------------
## Hourly data
##-------------------------------------------------------------------------------

jq -r '.[] | [.dt, .temp, .weather[].description, .wind_speed,
    .humidity, .uvi, .pressure, .clouds, .pop,
    if(.rain."1h" | length)>0 then .rain."1h" else 0 end ] | @csv'\
        hourly_weather.json  \
        | awk 'BEGIN{FS=","; OFS=",";
           # print "Day,Temp,Desc,Wind,POP,Hum,UVI,Pres,Cloud,Rain"
        } {
                gsub(/"/, "");
                $1=strftime("%a-%d %H:%M", $1);
                $4=$4*3.6;
                $9=$9*100;
                print }' > table_complete.csv

##-------------------------------------------------------------------------------
## Daily data
##-------------------------------------------------------------------------------

jq '.[] | [
    .dt,
    .temp.max,
    .temp.min,
    .weather[].description,
    .wind_speed,
    .humidity,
    .uvi,
    .pressure,
    .clouds,
    .pop,
    if(.rain | length)>0 then .rain else 0 end,
    .sunrise,
    .sunset,
    .moonrise,
    .moonset,
    .moon_phase,
    .temp.day,
    .temp.night,
    .temp.eve,
    .temp.morn,
    .dew_point,
    .wind_deg,
    .wind_gust,
    .weather[].id,
    .weather[].main,
    .weather[].icon
     ] | @csv ' daily_weather.json \
        | awk 'BEGIN{FS = ","; OFS = ","}{
                gsub(/\\?"/, "");
                $1=strftime("%a-%d", $1);
                $5=$5*3.6;
                $10=$10*100;
                $12=strftime("%H:%M", $12);
                $13=strftime("%H:%M", $13);
                $14=strftime("%H:%M", $14);
                $15=strftime("%H:%M", $15);
                $23=$23*3.6;
        print}' > daily_complete.csv

##-------------------------------------------------------------------------------
## Minutely data
##-------------------------------------------------------------------------------

jq -r '.[] | [ .dt, .precipitation] | @csv' minutely_weather.json \
    | awk 'BEGIN{FS = "," ; OFS = "," }{
        $1=strftime("%H:%M", $1);
        print}' > minutely.csv

##-------------------------------------------------------------------------------
## Alerts
##-------------------------------------------------------------------------------

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
printf "Next $HOURS_NBR hours:\n"
head -n $HOURS_NBR table_complete.csv \
    | column -t -s"," -N Time,Temp,Desc,Wind,Hum,UVI,Pres,Cloud,POP,Rain

printf "\n"

# Daily Table
printf "Next $DAYS_NBR days:\n"
cut -d, -f '1-11' daily_complete.csv |\
    head -n $DAYS_NBR |\
    column -t -s"," -N Day,Max,Min,Desc,Wind,Hum,UVI,Pres,Cloud,POP,Rain
printf "\n"

# Alerts
if [[ ( -s alerts.tsv && $aflag -eq 1 ) ]]
    then
        awk 'BEGIN{FS="\t"; print "ALERTS"}{
            printf "Event: %s\n", $2
            printf "From: %s to %s\n", $3, $4
            printf "Description: %s\n", $5
        }' alerts.tsv
fi

#-------------------------------------------------------------------------------
