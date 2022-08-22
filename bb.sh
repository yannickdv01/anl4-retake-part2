#!/bin/bash
#set -Eeuxo pipefail

dirReport=""
prevDirReports=()

badWords=""
badWordsArray=("bad")

configured=0

errorInRun=0

#cancelExecution=0

function log() {
	errorInRun=1

    logStr="[$(date +%Y-%m-%dT%H:%M:%S%z)] $1"
    dest="$HOME/log.txt"

    # Check if we have a log file in the home directory
    if [ -f "$dest" ]; then
        echo "$logStr" >> "$dest"
    else
        echo "$logStr" > "$dest"
    fi
}

function report() {
    reportStr="$1, $2, $dirReport, $3"
    dest="$dirReport/report.csv"

    if [ -f "$dest" ]; then
        echo "$reportStr" >> "$dest"
    else
        echo "Source, New name, Destination, Word" > "$dest"
        echo "$reportStr" >> "$dest"
    fi
}

function print()
{
    echo "$1" >&2
}

function copyToArchive {
    file="$1"
    word="$2"

    owner=$(stat -c '%U' "$file")

    creationDate=$(stat -c '%w' "$file")

    # If creation date is not set or is "-" log error
    if [ -z "$creationDate" ] || [ "$creationDate" == "-" ]; then
        log "Error: Creation date is not set for $file, the current filesystem may not support this feature."
        creationDate=""
    fi
    
    date=$(echo "$creationDate" | cut -d ' ' -f 1)
    
    base=$(basename "$file")
    extension="${base##*.}"
    filename="${base%.*}"

    if [ ! -f  "$dirReport/$owner-$date-$filename.$extension" ]; then
        cp "$file" "$dirReport/$owner-$date-$filename.$extension"
        
        report "$file" "$owner-$date-$filename.$extension" "$word"
    else
        count=1
        while [ -f "$dirReport/$owner-$date-$filename$count.$extension" ]; do
            count=$((count+1))
        done
        cp "$file" "$dirReport/$owner-$date-$filename$count.$extension"

        report "$file" "$owner-$date-$filename.$extension" "$word"
    fi
}

function createArchiveFolder {
    destination="./Archive"
    if [ ! -d "$destination" ]; then
        mkdir -p "$destination"

        # Save the absolute path of the folder
        destination=$(readlink -f $destination)
    else
        count=1
        newDestination="$destination"
        while [ -d "$newDestination" ]; do
            newDestination="$destination$count"
            count=$((count+1))
        done

        mkdir -p "$newDestination"

        # Save the absolute path of the folder
        destination=$(readlink -f "$newDestination")
    fi

    echo "$destination"
}

function parseArguments {
	args=("$@")

	# Loop through all arguments
	wasPrevValid=0
	for arg in "${args[@]}"; do
		# Check if the argument starts with a "-" or if the previous argument was valid
		if [ "${arg:0:1}" == "-" ] || [ "$wasPrevValid" -eq 1 ]; then
			wasPrevValid=1

			if [ "${arg:0:1}" != "-" ]; then
				wasPrevValid=0
			fi
		else
			echo "ERROR: $arg is not a valid argument" >&2
			bash
		fi
	done
	
	# Reset the getopts internal state
	OPTIND=1

    while getopts ":d:b:" opt; do
        case "${opt}" in
            d)
                echo "Option $opt: $OPTARG"
                #check if dirreport is empty
                if [ -z "$dirReport" ]; then
                    dirReport="$OPTARG"
                else
                    print "Error: cant set dirreport twice"
                    log "Error: dirreport is already set to $dirReport"
                    bash
                fi
                ;;
            b)
                echo "Option $opt: $OPTARG"
                #check if badwords is empty
                if [ -z "$badWords" ]; then
                    badWords="$OPTARG"
                else
                    print "Error: cant set badwords twice"
                    log "Error: badwords is already set to $badWords"
                    bash
                fi
                ;;
            :)
                #cancelExecution=1
                #print "Invalid option"
                print "ERROR: At least 1 valid argument has to be supplied" >&2
                bash
                ;;
            \?)
                #cancelExecution=1
                #print "Requires option"
                print "ERROR: -$OPTARG is not a valid option" >&2
                bash
                ;;
        esac
    done
}

function dirReportExists {
    if [ -d "$1" ]; then
        #if dirreport does exist, print error message and exit
        echo 1
    else
        echo 0
    fi
}


#function to read badwords file and create array of badwords
function readBadWords {
    if [ -n "$1" ]; then
        #check if badwords file exists
        if [ -f "$1" ]; then
            #if badwords file exists, check if badwords file is empty
            if [ -s "$1" ]; then
                badWordsArray=()
                #if badwords file is not empty, read badwords file and create array of badwords
                while read -r line; do
                    badWordsArray+=("$line")
                done < "$1"
            fi
        else
            # if badwords file does not exist, print error message and exit
            print "ERROR: Badwords file does not exist" >&2
            log "ERROR: badwords file does not exist"
            bash
        fi
    fi
}

function configureBB {  
    dirReport=""
    badWords=""
    badWordsArray=("bad")
    configured=0
    currentWD=$(pwd)

	# If there are any arguments, parse them
	if [ $# -gt 0 ]; then
		parseArguments "$@"
	fi

    exists=$(dirReportExists "$dirReport")

    # If dirReport is empty, create it else check if it is a directory
    if [ "$dirReport" == "" ]; then
        dirReport=$(createArchiveFolder)
    elif [ "$exists" == 0 ]; then
        print "ERROR: '$dirReport' is not an existing directory" >&2
        log "ERROR: '$dirReport' is not an existing directory"
        bash
    fi

    readBadWords "$badWords"
    configured=1
}

function debugVars {
	echo "configured: $configured"
    echo "dirReport: $dirReport"
    echo "badWords:"
    for word in "${badWordsArray[@]}"; do
        echo "$word"
    done

	echo "prevDirReports:"
	for prevDirReport in "${prevDirReports[@]}"; do
		echo "$prevDirReport"
	done
}

function realRunBB()
{
	# Add the dirReport to prevDirReports
	prevDirReports+=("$dirReport")

    # Loop through all files in the current working directory
    find . -type f -print0 | while IFS= read -r -d '' file; do
        # Ignore files in the archive folder
        if [[ "$file" == *$dirReport* ]]; then
            continue
        fi

		inPrev=0
		# Ignore the file if it is in any of the prevDirReports folders
		for prevDirReport in "${prevDirReports[@]}"; do
			if [[ "$file" == *$prevDirReport* ]]; then
				inPrev=1
				break
			fi
		done
		if [ $inPrev -eq 1 ]; then
			continue
		fi

        # If the file size is 0, skip it
        if [ -s "$file" ]; then
            type=$(file -0 "$file")
            # Check if the file is a text file by checking if type contains "text"
            if [[ $type == *"text"* ]]; then
                # Scan the file for bad words
                for word in "${badWordsArray[@]}"; do
                    if grep -q "$word" "$file"; then
                        # If a bad word is found, copy the file to the archive folder
                        copyToArchive "$file" "$word"
                        break
                    fi
                done
            fi
        fi
    done  
    configured=0 

	if [ $errorInRun -eq 1 ] ; then
		echo "There was an error in the execution, for more details check log.txt in the home directory." >&2
	fi
}

function runBB()
{
	errorInRun=0

	passChecks=1
    #check is currentWD matches the current working directory
    if [ "$currentWD" != "$(pwd)" ]; then
        print "ERROR: current working directory does not match the working directory of configureBB" >&2
        log "ERROR: current working directory does not match the working directory of configureBB"

        passChecks=0
    fi
    #check if there are any arguments
    if [ $# -gt 0 ]; then
        #give error message if there are any arguments
        print "ERROR: No arguments are allowed" >&2
        log "ERROR: No arguments are allowed"
		
		passChecks=0
    fi
	if [ $configured -eq 0 ]; then
        #configureBB must be run after every runBB for safety reasons (in case of someone spamming runBB and clunking up space)
        echo "ERROR: configureBB has not been run, please configure first. Or in case runBB is done, reconfigure." >&2
		log "ERROR: configureBB has not been run"

		passChecks=0
    fi

	if [ $passChecks -eq 1 ]; then
		realRunBB > /dev/null 2>&1 &
		#realRunBB
	fi
}