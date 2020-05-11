#!/bin/bash

#==============Variables==================
#==============IEXCloud===================
SECRET="$IEX_SECRET"
IEX_VERSION=stable
case "$SECRET" in
	Tsk_*)	BASE_URL="https://sandbox.iexapis.com/${IEX_VERSION}";;
	*)		BASE_URL="https://cloud.iexapis.com/${IEX_VERSION}"
esac
#==============Colors=====================
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\e[93m'
COLOR_GREEN='\e[92m'
COLOR_DEFAULT='\033[0m'
COLOR_DIM='\e[2m'
#==============Lines======================
#     0   1   2   3   4   5   6   7   8   9   10
box=("╔" "═" "╗" "║" "╝" "╚" "╦" "╠" "╣" "╩" "╬")
#==============System=====================
case "$(uname -s)" in
	Linux*)  system=Linux;;
	Darwin*) system=MacOS;;
	CYGWIN*) system=Cygwin;;
	MINGW*)  system=MinGw;;
	*)       system="Other"
esac
LOG_PATH=~/.config/stocks
LOG_FILE="${LOG_PATH}/stocks.log"
CONFIG_PATH="~/.config/stocks"
CONFIG_FILE="${CONFIG_PATH}/config"
DELAY=60; #dealy in seconds
#==============End Variables==============

#INFO: Prints timestamp and log message to log file
#INPUT: Log Message
#RETURN: null
function write_log(){
	#CReate folder if it does not exist
	mkdir -p "${LOG_PATH}"

	local timestamp=$(date +'%D %T')
	if [[ -z "$1" ]]; then
		$(printf "[${timestamp}] ${COLOR_YELLOW}No Message was given.${COLOR_DEFAULT}\n" >> "${LOG_FILE}")
	else
		$(printf "[${timestamp}] ${1}\n" >> "${LOG_FILE}")
	fi
}
#INFO: TODO
#INPUT: null
#RETURN: null
function load_config(){
	echo "TODO"
}

#INFO: TODO
#INPUT: null
#RETURN: null
function write_config(){
	echo "TODO"
}
#INFO: Initializes the bash script with settings and validations
#INPUT: null
#RETURN: null
function init(){
	rm "${LOG_FILE}"
	#Validate curl is installed
	if command -v curl >/dev/null 2>&1; then 
		curled=1; 
	else 
		write_log "${COLOR_RED}ERROR:${COLOR_DEFAULT} Curl is a required dependency."
		printf "${COLOR_RED}ERROR:${COLOR_DEFAULT} Curl is a required dependency.\n"
		printf "       Stopping...\n"
		exit 1
	fi
	#Validate jq is installed
	if command -v jq >/dev/null 2>&1; then 
		jqed=1; 
	else 
		write_log "${COLOR_RED}ERROR:${COLOR_DEFAULT} jq is a required dependency."
		printf "${COLOR_RED}ERROR:${COLOR_DEFAULT} jq is a required dependency.\n"
		printf "       Stopping...\n"
		exit 1
	fi

	symbols=();
	symbols_data=();
	screen="";
	last_update=0;

	load_config;
	read w_height w_width < <(stty size)

	trap quit EXIT

	write_log "${COLOR_GREEN}OK:${COLOR_DEFAULT} Initiated successfully..."
}

#INFO: Generates the url for curl call
#INPUT: API path
#RETURN: full URL to curl against
function generate_call(){

	local path="$1"
	if [[ "$path" == /* ]]; then
		echo "${BASE_URL}${path}?token=${SECRET}"
	else
		write_log "${COLOR_RED}ERROR:${COLOR_DEFAULT} The supplied path ( ${path} ) is missing the first '/'."
		printf "${COLOR_RED}ERROR:${COLOR_DEFAULT} The supplied path ( $path ) is missing the first '/'\n"
		printf "       Stopping...\n"
		exit 1
	fi
}

#INFO: Adds symbol to the array list
#INPUT: Symbol
#RETURN: null
function add_symbol(){
	#Check that a symbol was provided to function call
	if [[ ! -z "$1" ]]; then
		local url=$(generate_call "/stock/${1}/quote")
		local symbol_check="$(curl -is "$url" | grep -P '^HTTP\/[0-9](.[0-9]|) ' | grep -oP '\d\d\d')"
		
		#Check that the symbol exists
		if [[ "$symbol_check" == "200" ]]; then
			symbols+=( "$1" )
		else
			write_log "${COLOR_YELLOW}WARNING:${COLOR_DEFAULT} Symbol ( ${1} ) does not exist. Call: ${url}."
		fi
	fi
}

#INFO: Used for centering a string in the tab
#INPUT: Max Length, String
#RETURN: String
function centering(){
	local str="$2"
	local diff=$((($1 - ${#str}) / 2))
	printf "%${diff}s%s%${diff}s" "" "$str" "" 
}

#INFO: Prints the header lines and values
#INPUT: null
#RETURN: null
function print_header(){
	headers=( "Tag" "Price" 'Change' "Change" "Open")
	size=$((("$w_width" - 2) / ("${#headers[@]}" )))
	
	#Print top Line
	screen+="${box[0]}"
	for (( i=0; i<"$w_width"-2; i++)); do
		screen+="${box[1]}"
	done
	screen+="${box[2]}\n"
	#End Top Line

	#Start headers values
	screen+="${box[3]}"
	local total_spacing=1
	for item in "${headers[@]}"; do
		local value=$(centering $size $item )
		screen+="$value"
		total_spacing=$(($total_spacing + ${#value}))
	done 
	screen+=$(printf "%$(($w_width - ($total_spacing - 2)))s" "${box[3]}");
	screen+="\n"
	#End header

	#Start end line	
	screen+="${box[7]}"
	for (( i=0; i<"$w_width"-2; i++)); do
		screen+="${box[1]}"
	done
	screen+="${box[8]}\n"
	#End end line
}

#INFO: Prints each symbol line and additional lines to fill screen
#INPUT: null
#RETURN: null
function print_body(){
	#Get the number of rows after Symbols
	local additional=$(expr $w_height - 4 - ${#symbols[@]})
	#Loop through every Symbol
	for response in "${symbols_data[@]}"; do
		screen+="${box[3]}"
		#Determine if the print color should be green or red
		local curr_price="$(echo $response | jq .latestPrice )"
		local open="$(echo $response | jq .open )"
		local color=""
		if [[ "$open" > "$curr_price" ]]; then
			local color="$COLOR_RED"
		else
			local color="$COLOR_GREEN"
		fi

		#Print each symbol tab data
		local value="";
		local total_spacing=1

		value=$(centering $size "$(echo "$response" | jq .symbol | grep -oP '"\K.*[^"]')")
		total_spacing=$(($total_spacing + ${#value}))
		screen+="${color}${value}${COLOR_DEFAULT}"

		value=$(centering $size "\$$(echo $response | jq .latestPrice )")
		total_spacing=$(($total_spacing + ${#value}))
		screen+="${color}${value}${COLOR_DEFAULT}"

		value=$(centering $size "$(echo $response | jq .changePercent )")
		total_spacing=$(($total_spacing + ${#value}))
		screen+="${color}${value}${COLOR_DEFAULT}"

		value=$(centering $size "\$$(echo $response | jq .change )")
		total_spacing=$(($total_spacing + ${#value}))
		screen+="${color}${value}${COLOR_DEFAULT}"

		value=$(centering $size "\$$(echo $response | jq .open )")
		total_spacing=$(($total_spacing + ${#value}))
		screen+="${color}${value}${COLOR_DEFAULT}"

		#Print closing line
		screen+=$(printf "%$(($w_width - ($total_spacing - 2)))s" "${box[3]}");
		screen+="\n"
	done

	#Print all additional lines
	for ((i=0; i<"$additional"; i++)); do
		screen+=$(printf "%-$(expr ${w_width} + 1)s" "${box[3]}")
		screen+="${box[3]}\n"
	done
}

#INFO: Prints the final line and control information
#INPUT: null
#RETURN: null
function print_footer(){
	screen+="${box[5]}"
	local temp=$(echo  "$((("$w_width" - 29 ) / 4))")
	for (( i=0; i<"$w_width"-29; i++)); do
		case "$i" in
			"$(("$temp" ))")  			screen+=" ${COLOR_DIM}↑${COLOR_DEFAULT} SELECT ${COLOR_DIM}↓${COLOR_DEFAULT}  ";;
			"$((("$temp" * 2)))")		screen+=" ${COLOR_DIM}+${COLOR_DEFAULT} ADD ";;
			"$((("$temp" * 3)))")  		screen+=" ${COLOR_DIM}←${COLOR_DEFAULT} DELETE ";;
			*)       					screen+="${box[1]}"
		esac
	done
	screen+="${box[4]}"
}

#INFO: Print functions wrapper
#INPUT: null
#RETURN: null
function print(){
	screen="";
	print_header;
	print_body;
	print_footer;
	clear;
	printf "$screen"
	printf "\033[?25l"
}

#INFO: Curls the url and pulls symbol data, only runs curl every $DELAY
#INPUT: null
#RETURN: null
function get_symbols_data(){
	if [[ $(($(date +'%s') - $last_update)) -gt "$DELAY" ]]; then
		symbols_data=();
		for item in "${symbols[@]}"; do
			local url=$(generate_call "/stock/${item}/quote" )
			local response=$(curl -s "$url" | jq '{symbol : .symbol, latestPrice: .latestPrice, changePercent: .changePercent, change: .change, open: .open }')
			symbols_data+=( "$response" )
		done
		write_log "${COLOR_GREEN}OK:${COLOR_DEFAULT} Pulled symbol data..."
		last_update=$(date +'%s')
		print;
	fi
}

#INFO: Checks and reprints the screen on a resize
#INPUT: null
#RETURN: null
function resize(){
	if [[ $(stty size) != "$w_height $w_width" ]]; then 
		read w_height w_width < <(stty size); 
		print;
	fi
}

function quit(){
	printf "\033[?25h"
	write_config
}

function main(){

	init;
	print;

	for symbol in "$@"; do
		add_symbol "$symbol"
	done

	#start loop
	while true; do
		get_symbols_data;
		resize;
		sleep 1s;
	done;
	#End loop
}

main "$@";
