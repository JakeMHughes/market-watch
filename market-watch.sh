#!/bin/bash

#==============Variables==================
#==============IEXCloud===================
SECRET=$IEX_SECRET
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
LOG_PATH=~/.config/market-watch
LOG_FILE="${LOG_PATH}/market-watch.log"
DELAY=60; #dealy in seconds
#==============End Variables==============

#INFO: 		Deletes an element from both symbol arrays
#INPUT:		The index number
#RESTURN: 	NULL
function delete_symbol_element(){
	local temp_symbol_data=();
	local temp_symbol=();
	for (( i=0; i<"${#symbols[@]}"; i++ )); do
		if [ "$i" -ne "$1" ]; then
			temp_symbol_data+=( "${symbols_data[$i]}" )
			temp_symbol+=( "${symbols[$i]}" )
		fi
	done;
	symbols=( "${temp_symbol[@]}" )
	symbols_data=( "${temp_symbol_data[@]}" )
}

#INFO: 		Prints timestamp and log message to log file
#INPUT: 	Log Message
#RETURN: 	NULL
function write_log(){
	#Create folder if it does not exist
	mkdir -p "${LOG_PATH}"

	local timestamp=$(date +'%D %T')
	if [[ -z "$1" ]]; then
		$(printf "[${timestamp}] ${COLOR_YELLOW}No Message was given.${COLOR_DEFAULT}\n" >> "${LOG_FILE}")
	else
		$(printf "[${timestamp}] ${1}\n" >> "${LOG_FILE}")
	fi
}

#INFO: 		Initializes the bash script with settings and validations
#INPUT: 	NULL
#RETURN: 	NULL
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

	#Setup global variables
	symbols=();
	symbols_data=();
	screen="";
	last_update=0;
	current_idx=$((0))

	read w_height w_width < <(stty size)

	trap quit EXIT

	printf "\033[?25l"

	write_log "${COLOR_GREEN}OK:${COLOR_DEFAULT} Initiated successfully..."
}



#INFO: 		Generates the url for curl call
#INPUT: 	API path
#RETURN: 	Full URL to curl against
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

#INFO: 		Adds symbol to the array list
#INPUT: 	Symbol
#RETURN: 	NULL
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

#INFO: 		Used for centering a string in the tab
#INPUT: 	Max Length, String
#RETURN: 	String
function centering(){
	local str="$2"
	local diff=$((($1 - ${#str}) / 2))
	printf "%${diff}s%s%${diff}s" "" "$str" "" 
}

#INFO: 		Prints the header lines and values
#INPUT: 	NULL
#RETURN: 	NULL
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

#INFO: 		Prints Only the specified symbol
#INPUT: 	Symbol, Selection escape code
#RETURN: 	String line
function print_symbol(){

	local value="";
	local total_spacing=1
	local line=""
	local response=$1

	local curr_price="$(echo $response | jq .latestPrice )"
	local open="$(echo $response | jq .open )"
	local curr_symbol="$(echo "$response" | jq .symbol | grep -oP '"\K.*[^"]')"
	local change_percent="$(echo $response | jq .changePercent )"
	local change_val="\$$(echo $response | jq .change )"

	local symbol_values=( "$curr_symbol" "$curr_price" "$change_percent" "$change_val" "$open" )

	local color=""
	if [[ "$open" > "$curr_price" ]]; then
		color="$COLOR_RED"
	else
		color="$COLOR_GREEN"
	fi

	line+="${box[3]}"
	line+="${2}"

	for item in "${symbol_values[@]}"; do
		value=$(centering $size $item)
		total_spacing=$(($total_spacing + ${#value}))
		line+="${value}"
	done

	#Print closing line
	line+=$(printf "%$(($w_width - ($total_spacing + 1)))s" "");
	line+=$(printf "${COLOR_DEFAULT}${box[3]}")
	line+="\n"

	printf "${line}"

}

#INFO: 		Prints each symbol line and additional lines to fill screen
#INPUT: 	NULL
#RETURN: 	NULL
function print_body(){
	#Get the number of rows after Symbols
	local additional=$(expr $w_height - 4 - ${#symbols[@]})
	#Loop through every Symbol
	local idx=1;
	for response in "${symbols_data[@]}"; do

		#Determine if the print color should be green or red
		local selection=""
		if [ $current_idx -eq $idx ]; then
			selection="\033[7m"
		fi;

		#Print each symbol tab data
		screen+="$(print_symbol "$response" "$selection")\n"

		idx=$(($idx + 1))
	done

	#Print all additional lines
	for ((i=0; i<"$additional"; i++)); do
		screen+=$(printf "%-$(expr ${w_width} + 1)s" "${box[3]}")
		screen+="${box[3]}\n"
	done
}

#INFO: 		Prints the final line and control information
#INPUT: 	NULL
#RETURN: 	NULL
function print_footer(){
	screen+="${box[5]}"
	local timestamp=$(date +'%T')
	local temp=$(echo  "$((("$w_width" - 40 ) / 4))")
	for (( i=0; i<"$w_width"-40; i++)); do
		case "$i" in
			2)							screen+=" [$timestamp] ";; #12
			"$((("$temp" )))")  		screen+=" ${COLOR_DIM}↑${COLOR_DEFAULT} SELECT ${COLOR_DIM}↓${COLOR_DEFAULT}  ";;
			"$((("$temp" * 2)))")		screen+=" ${COLOR_DIM}+${COLOR_DEFAULT} ADD ";;
			"$((("$temp" * 3)))")  		screen+=" ${COLOR_DIM}←${COLOR_DEFAULT} DELETE ";;
			*)       					screen+="${box[1]}"
		esac
	done
	screen+="${box[4]}"
}

#INFO: 		Print functions wrapper
#INPUT: 	NULL
#RETURN: 	NULL
function print(){
	screen="";
	print_header;
	print_body;
	print_footer;
	clear;
	printf "$screen"
}

#INFO: 		Curls the url and pulls symbol data, only runs curl every $DELAY
#INPUT: 	NULL
#RETURN: 	NULL
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

#INFO: 		Checks and reprints the screen on a resize
#INPUT: 	NULL
#RETURN: 	NULL
function resize(){
	if [[ $(stty size) != "$w_height $w_width" ]]; then 
		read w_height w_width < <(stty size); 
		print;
	fi
}

#INFO: 		Runs final commands to cleanup on exit
#INPUT: 	NULL
#RETURN: 	NULL
function quit()	{ printf "\033[?25h"; clear; }

#INFO: 		Moves the cursor to the specified row, rows start at 1
#INPUT: 	row number
#RETURN: 	NULL
function cursor_to() { printf "\033[${1};0H"; }

#INFO: 		Handles the selection highlight logic and the key presses
#INPUT: 	NULL
#RETURN: 	NULL
function get_selection() {

	key_input(){
	    read -sn1 -t0.5 t;
	    case $t in
	        'A') echo up ;;
	        'B') echo down ;;
			'+') echo add ;;
			'3') echo delete;;
	    esac;
	}

	case `key_input` in
		up)		if [ $current_idx -ne 0 ]; then
					cursor_to $(($current_idx + 3))
					print_symbol "${symbols_data[$(($current_idx - 1))]}" "${COLOR_DEFAULT}"
				fi;
				if [ "$current_idx" -le 0 ]; then 
					current_idx=$((0))
				else
					current_idx=$((current_idx - 1))
					cursor_to $(($current_idx + 3))
					print_symbol "${symbols_data[$(($current_idx - 1))]}" "\033[7m"
				fi
				print;;
		down)	if [ $current_idx -ne 0 ]; then
					cursor_to $(($current_idx + 3))
					print_symbol "${symbols_data[$(($current_idx - 1))]}" "${COLOR_DEFAULT}"
				fi;
				if [ $current_idx -eq "${#symbols[@]}" ]; then
					current_idx=$((0))
				else
					current_idx=$((current_idx + 1))
					cursor_to $(($current_idx + 3))
					print_symbol "${symbols_data[$(($current_idx - 1))]}" "\033[7m"
				fi;;
		delete)	if [ $current_idx -ge 1 ]; then
					write_log "${COLOR_GREEN}OK:{COLOR_DEFAULT} Deleting element at index $(($current_idx - 1))"
					delete_symbol_element "$(($current_idx - 1))"
					current_idx=$((0));
					print;
				fi;;
		add) write_log "${COLOR_YELLOW}WARNING:{COLOR_DEFAULT} '+' button pressed but not coded.";;
	esac
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
		get_selection;
		#sleep 1s;
	done;
	#End loop
}
main "$@";
