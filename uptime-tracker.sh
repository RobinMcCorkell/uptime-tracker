#!/bin/bash

#The MIT License (MIT)
#
#Copyright (c) 2012-2013 Robin McCorkell
#
#Permission is hereby granted, free of charge, to any person obtaining a copy of
#this software and associated documentation files (the "Software"), to deal in
#the Software without restriction, including without limitation the rights to
#use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
#the Software, and to permit persons to whom the Software is furnished to do so,
#subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
#FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
#COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
#IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

version="2.8"

uptimefile="/var/spool/uptime-tracker/records"
filecontents=""
command=""
outputformat="d"
otherparams=""
optionhelp=false
readoptions=true
timestart="d"
timeend="d"

###################
#Utilites
###################

#check if file exists and is not empty
function _check_file {
	if [[ ! -s $uptimefile ]];  then
		false
	else
		true
	fi
	return
}
#error handling
function _no_data {
	echo "No data found" >&2
}

###################
#Formatting
###################

#convert UNIX timestamp to dd/mm/yyyy hh:mm:ss
function _to_date {
	date --date="@$1" "+%d/%m/%Y %T"
}
#convert seconds to full time
function _conv_time {
	local format=""
	if [[ $2 == "s" ]];  then
		format="%dd, %02dh, %02dm, %02ds"
	else
		format="%d days, %02d hours, %02d minutes, %02d seconds"
	fi
	printf "${format}\n" $(( $1 / 86400 )) $(( $1 / 3600 % 24 )) $(( $1 / 60 % 60 )) $(( $1 % 60 ))
}
#calculate percentage to 4 decimal places
function _calc_percentage {
	echo "$1 $2" | awk '{printf "%.4f\n", $1*100/$2}'
}
#pad to width with spaces
function _pad {
	printf "%-${2}s\n" "$1"
}

#convert a date according to set options
function _conv_date_opt {
	case "$outputformat" in
	n)
		_to_date "$1"
		;;
	*)
		echo "$1"
		;;
	esac
}
#convert a time according to set options
function _conv_time_opt {
	case "$outputformat" in
	p)
		if [[ $2 =~ ^[0-9]*+$ ]]; then
			_calc_percentage $1 $2
		else
			echo $1
		fi
		;;
	n)
		_conv_time $1 $2
		;;
	*)
		echo $1
		;;
	esac
}

###################
#Session
###################

#get current uptime of this session
function session_uptime {
	local uptime=$(cut -d " " -f 1 /proc/uptime)
	echo ${uptime%.*}
}
#get boot time of this session
function session_boottime {
	echo $(( $(date +%s) - $(session_uptime) ))
}

###################
#File
###################

#get boot time for session $1
function file_session_boottime {
	if [[ $1 ]];  then
		echo $(sed "$(( ($1 * 2) -  1 ))q;d" <<< "$filecontents")
	fi
}
#get uptime for session $1
function file_session_uptime {
	if [[ $1 ]];  then
		shopt -s extglob
		local uptime=$(sed "$(( $1 * 2 ))q;d" <<< "$filecontents")
		echo ${uptime%%*([^0-9])}
	fi
}
#number of sessions in file
function file_session_count {
	echo $(( $(wc -l <<< "$filecontents") / 2 ))
}
#get time at end of session $1
function file_session_endtime {
	if [[ $1 ]];  then
		echo $(( $(file_session_boottime $1) + $(file_session_uptime $1) ))
	fi
}
#return true if session $1 had a power failure
function file_session_failed {
	local ret=false
	if [[ $1 ]]; then
		local uptime_line=$(sed "$(( $1 * 2 )) { s/^\([^ ]*\).*/\1/; q };d" <<< "$filecontents")
		if [[ ${uptime_line:$(( ${#uptime_line} - 1 )):1} == "*" ]]; then
			ret=true
		fi
	fi
	$ret
}
#get time between first recorded boot and last update
function file_total_time {
	echo $(( $(file_session_endtime $(file_session_count)) - $(file_session_boottime 1) ))
}
#get total reported uptime between limits
function file_total_uptime {
	local entries=$(file_session_count)
	local uptime=0
	for (( i = $entries; i > 0; --i )); do
		local boottime=$(file_session_boottime $i)
		local endtime=$(file_session_endtime $i)
		if (( endtime < timestart )); then
			break
		elif (( boottime < timeend )); then
			(( uptime += ( (endtime<timeend?endtime:timeend) - (boottime>timestart?boottime:timestart) ) ))
		fi
	done
	echo $uptime
}
#update uptime information in file
function file_update_uptime {
	local uptimedir=$(dirname "$uptimefile")
	if [[ ! -d $uptimedir ]]; then
		echo "WARNING: $uptimedir did not exist, creating" >&2
		mkdir -p "$uptimedir"
	fi
	local uptime=$(session_uptime)
	local now=$(date +%s)

	if ! _check_file ; then
		echo $(session_boottime) >> "$uptimefile"
		echo $uptime >> "$uptimefile"
	else
		file_prepare
		if [[ $(session_boottime) -lt $(file_session_endtime $(file_session_count)) ]];  then
			uptime=$(( $now - $(file_session_boottime $(file_session_count)) ))
			sed -i "\$s/.*/$uptime/" "$uptimefile"
		else
			echo $(session_boottime) >> "$uptimefile"
			echo $uptime >> "$uptimefile"
		fi
	fi
}
#set fail for the current session
function file_fail_set {
	if ! file_session_failed $(file_session_count); then
		sed -i "\$s/\$/*/" "$uptimefile"
	fi
}
#unset fail for the current session
function file_fail_unset {
	sed -i "\$s/.*/$(file_session_uptime $(file_session_count))/" "$uptimefile"
}
#read the file and set some defaults
function file_prepare {
	#Read the file
	if ! _check_file; then
		_no_data
		exit 3
	fi
	filecontents=$(< "$uptimefile")

	#Set some defaults
	[[ $timestart == "d" ]] && timestart=$(file_session_boottime 1)
	[[ $timeend == "d" ]] && timeend=$(file_session_endtime $(file_session_count))
}
#get reason for session $1
function file_reason_get {
	if [[ $1 ]]; then
		sed "$(( $1 * 2 )) { s/^[^ ]* \?//; q }; d" <<< "$filecontents"
	fi
}
#set reason for session $1 to $2
function file_reason_set {
	if [[ $1 ]] && [[ $2 ]]; then
		#Don't question the regex - I could have used ${2//\//\\\/} instead!
		sed -i "$(( $1 * 2 )) { s/ .*//; s@\$@ ${2//@/\\@}@ }" "$uptimefile"
	fi
}

###################
#Output
###################

#output downtime
function output_downtime {
	local outputformat=$outputformat
	[[ $1 ]] && outputformat=$1
	if _check_file; then
		local totaltime=$(( timeend - timestart ))
		local totaldowntime=$(( $totaltime - $(file_total_uptime) ))
		_conv_time_opt $totaldowntime $totaltime
	else
		_no_data
		exit 3
	fi
}
#output uptime
function output_uptime {
	local outputformat=$outputformat
	[[ $1 ]] && outputformat=$1
	if _check_file; then
		local totaltime=$(( timeend - timestart ))
		local totaluptime=$(file_total_uptime)
		_conv_time_opt $totaluptime $totaltime
	else
		_no_data
		exit 3
	fi
}
#output all data
function output_all_data {
	local outputformat=$outputformat
	[[ $1 ]] && outputformat=$1
	if _check_file; then
		local entry_count=$(file_session_count)
		local current_session=true
		if (( $(session_boottime) > $(file_session_endtime $entry_count) ));  then
			(( ++entry_count ))
			current_session=false
		fi
		for (( i = 1; i < $entry_count; ++i)); do
			local boottime=$(file_session_boottime $i)
			local endtime=$(file_session_endtime $i)
			(( boottime < timeend )) || return
			if (( endtime > timestart )); then
				local outputstring="$boottime,$endtime"
				file_session_failed $i && outputstring+='*'
				echo "$outputstring"
			fi
		done
		if $current_session; then
			boottime=$(file_session_boottime $i)
			if (( boottime < timeend )); then
				echo $boottime
			fi
		fi
	else
		_no_data
		exit 3
	fi
}
#output first boot time
function output_start_time {
	local outputformat=$outputformat
	[[ $1 ]] && outputformat=$1
	if _check_file; then
		local starttime=$(file_session_boottime 1)
		_conv_date_opt $starttime
	else
		_no_data
		exit 3
	fi
}
#output latest update time
function output_end_time {
	local outputformat=$outputformat
	[[ $1 ]] && outputformat=$1
	if _check_file; then
		local endtime=$(file_session_endtime $(file_session_count))
		_conv_date_opt $endtime
	else
		_no_data
		exit 3
	fi
}
#output help
function display_help {
	echo "Uptime Tracker v$version" >&2
	echo "Copyright (c) 2012-2013 Robin McCorkell" >&2
	echo >&2
	echo "Data file is: $uptimefile" >&2
	echo "Session boot time is: $(_to_date $(session_boottime))" >&2
	echo "Usage: $0 [options] command" >&2
	echo >&2
	echo "Options: " >&2
	echo "  -n, --natural            output in full date format" >&2
	echo "  -r, --raw                default, output in UNIX timestamp" >&2
	echo "  -p, --percent            output downtime as percentage" >&2
	echo "      --file=[file]        store uptime data in [file]" >&2
	echo "      --time-start=[time]  only use entries newer than [time]" >&2
	echo "      --time-end=[time]    only use entries older than [time]" >&2
	echo >&2
	echo "Commands:" >&2
	echo "  update        update uptime file with latest information" >&2
	echo "  reset         clear downtime data and restart uptime counter" >&2
	echo "  auto [n]      run forever, updating automatically every [n] seconds" >&2
	echo "  start-time    print first recorded boot time" >&2
	echo "  end-time      print last recorded update time" >&2
	echo "  downtime      print downtime since first recorded boot" >&2
	echo "  uptime        print uptime since first recorded boot" >&2
	echo "  summary       print table of all information, in a human readable format" >&2
	echo "  raw <format>  print raw data, in one of the available formats - see README.md" >&2
	echo "  reason <cmd>  manage reasons for shutdowns" >&2
	echo >&2
	echo "Raw formats:" >&2
	echo "  all-data      all available data for each session" >&2
	echo "  state         relative time spent in each state" >&2
	echo >&2
	echo "Reasons:" >&2
	echo "  get <id>       get reason for session <id>" >&2
	echo "  set <id> <str> set reason for session <id> to <str>" >&2
}
#output full data table
function output_summary_table {
	local entry_count=$(file_session_count)
	local current_session=true
	if (( $(session_boottime) > $(file_session_endtime $entry_count) ));  then
		(( ++entry_count ))
		current_session=false
	fi
	for (( i = 1; i < $entry_count; ++i )); do
		local boottime=$(file_session_boottime $i)
		local endtime=$(file_session_endtime $i)
		(( boottime < timeend )) || return
		if (( endtime > timestart )); then
			echo -e " $(_pad $i $1)   $(_pad "$(_conv_date_opt $boottime)" $2)   $(_pad "$(_conv_date_opt $endtime)" $2)   $(_pad "$(file_session_failed $i && echo '*')" $3)   $(_conv_time_opt $(file_session_uptime $i) s)"
		fi
	done
	if $current_session; then
		local boottime=$(file_session_boottime $i)
		if (( boottime < timeend )); then
			echo -e " $(_pad cur $1)   $(_pad "$(_conv_date_opt $boottime)" $2)   $(_pad "" $2)   $(_pad "" $3)   $(_conv_time_opt $(file_session_uptime $i) s)"
		fi
	fi
}
#output relative state lengths
function output_state {
	local entry_count=$(file_session_count)
	local total_time=$((timeend - timestart))
	local status_set=false
	local offset=$timestart
	for (( i = 1; i <= $entry_count; ++i )); do
		local boottime=$(file_session_boottime $i)
		local endtime=$(file_session_endtime $i)
		if (( boottime > timestart )); then
			if ! $status_set; then
				echo "down"
				status_set=true
			fi
			local boottime_mod=$(( (boottime<timeend?boottime:timeend) - offset ))
			_conv_time_opt $boottime_mod $total_time
			(( boottime < timeend )) || return
			(( offset += boottime_mod ))
		fi
		if (( endtime > timestart )); then
			if ! $status_set; then
				echo "up"
				status_set=true
			fi
			local endtime_mod=$(( (endtime<timeend?endtime:timeend) - offset ))
			_conv_time_opt $endtime_mod $total_time
			(( endtime < timeend )) || return
			(( offset += endtime_mod ))
		fi
	done
}

###################
#Parsing
###################
function parse_options {
	if [[ ${1:0:1} == "-" ]];  then
		case "${1:1}" in
		help)
			optionhelp=true
			;;
		natural)
			outputformat="n"
			;;
		raw)
			outputformat="r"
			;;
		percent)
			outputformat="p"
			;;
		file=*)
			local file=${1:6}
			if [[ ! $file ]];  then
				echo "ERROR: No file specified" >&2
				exit 2
			fi
			uptimefile="$file"
			;;
		time-start=*)
			local time_start=${1:12}
			local time_now=$(date +%s)
			if [[ ! $time_start =~ ^[0-9]+$ ]] || (( time_start >= time_now )); then
				echo "ERROR: Invalid time-start" >&2
				exit 2
			fi
			timestart=$time_start
			;;
		time-end=*)
			local time_end=${1:10}
			local time_now=$(date +%s)
			if [[ ! $time_end =~ ^[0-9]+$ ]] || (( time_end >= time_now )) || (( time_end <= timestart )); then
				echo "ERROR: Invalid time-end" >&2
				exit 2
			fi
			timeend=$time_end
			;;
		"")
			readoptions=false
			;;
		*)
			echo "ERROR: Unknown option -$1" >&2
			exit 2
			;;
		esac
	else
		for (( i=0; i<${#1}; ++i )); do
			case "${1:$i:1}" in
			n)
				outputformat="n"
				;;
			r)
				outputformat="r"
				;;
			p)
				outputformat="p"
				;;
			*)
				echo "ERROR: Unknown option -${1:$i:1}" >&2
				exit 2
				;;
			esac
		done
	fi
}
function parse_command {
	command=$1
}
function parse_other {
	if [[ $otherparams ]]; then otherparams="$otherparams $1"
	else otherparams="$1"; fi
}

###################
#Arguments
###################
for arg in "$@"; do
	if [[ $arg == -* ]] && $readoptions;  then
		parse_options "${arg:1}"
	else
		if [[ ! $command ]];  then
			parse_command "$arg"
		else
			parse_other "$arg"
		fi
	fi
done

if $optionhelp; then
	display_help
	exit 1
fi

###################
#Command Processing
###################
case "$command" in
#debug-command)
#	eval "$otherparams"
#	;;
update)
	file_update_uptime
	;;
start-time)
	file_prepare
	output_start_time
	;;
end-time)
	file_prepare
	output_end_time
	;;
downtime)
	file_prepare
	output_downtime
	;;
uptime)
	file_prepare
	output_uptime
	;;
reset)
	> "$uptimefile"
	file_update_uptime
	;;
auto)
	interval=$(echo "$otherparams" | sed "s/.* \([^ ]*\)\$/\1/")
	if (( interval > 0 ));  then
		trap file_fail_unset EXIT
		while true; do
			file_update_uptime
			file_prepare
			file_fail_set
			sleep $interval
		done
	else
		echo "ERROR: Invalid interval specified" >&2
		exit 2
	fi
	;;
summary)
	file_prepare
	case "$outputformat" in
	p)
		outputformat="r"
		;;
	d)
		outputformat="n"
		;;
	esac
	id_width=5
	time_width=21
	fail_width=4
	if _check_file; then
		echo -e " $(_pad id $id_width) | $(_pad 'boot time' $time_width) | $(_pad 'shutdown time' $time_width) | $(_pad 'fail' $fail_width) | uptime"
		output_summary_table $id_width $time_width $fail_width
		echo
		echo "Last update: $(output_end_time)"
		echo "     Uptime: $(output_uptime) - $(output_uptime p)%"
		echo "   Downtime: $(output_downtime) - $(output_downtime p)%"
	else
		_no_data
		exit 3
	fi
	;;
raw)
	file_prepare
	subcommand=$(sed "s/^\([^ ]*\).*/\1/" <<< "$otherparams")
	case "$subcommand" in
	all-data)
		output_all_data
		;;
	state)
		[[ $outputformat == "n" ]] && outputformat="r"
		output_state
		;;
	*)
		echo "ERROR: Invalid raw format specified" >&2
		exit 2
		;;
	esac
	;;
reason)
	file_prepare
	subcommand=$(sed "s/^\([^ ]*\).*/\1/" <<< "$otherparams")
	case "$subcommand" in
	get)
		session_id=$(sed "s/^[^ ]* \([^ ]*\).*/\1/" <<< "$otherparams")
		entry_count=$(file_session_count)
		if (( session_id > 0 )) && (( session_id <= entry_count )); then
			file_reason_get $session_id
		else
			echo "ERROR: Invalid session ID" >&2
			exit 2
		fi
		;;
	set)
		session_id=$(sed "s/^[^ ]* \([^ ]*\).*/\1/" <<< "$otherparams")
		string=$(sed "s/^[^ ]* [^ ]* \(.*\)/\1/" <<< "$otherparams")
		entry_count=$(file_session_count)
		if (( session_id > 0 )) && (( session_id <= entry_count )) && [[ $string ]]; then
			file_reason_set $session_id "$string"
		else
			echo "ERROR: Invalid session ID or missing string" >&2
			exit 2
		fi
		;;
	*)
		echo "ERROR: Invalid reason command" >&2
		exit 2
		;;
	esac
	;;
"")
	echo "ERROR: No command specified - try --help" >&2
	exit 2
	;;
*)
	echo "ERROR: Invalid command $command - try --help" >&2
	exit 2
	;;
esac
