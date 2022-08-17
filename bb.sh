#!/bin/bash
set -Eeuxo pipefail

dirReport=""

badWords=""
badWordsArray=("bad")

configured=0

#cancelExecution=0

function log() {
    echo "There was an error in the execution, for more details check log.txt in the home directory." >&2

    # Check if we have a log file in the home directory
    if [ -f "$HOME/log.txt" ]; then
        echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] $1" >> "$HOME/log.txt"
    else
        echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] $1" > "$HOME/log.txt"
    fi
}

function print()
{
    echo "$1" >&2
}

function copyToArchive {
    owner=$(stat -c '%U' "$1")

    creationDate=$(stat -c '%w' "$1")

    # If creation date is not set or is "-" log error
    if [ -z "$creationDate" ] || [ "$creationDate" == "-" ]; then
        log "Error: Creation date is not set for $1, the current filesystem may not support this feature."
        creationDate=""
    fi
    
    date=$(echo "$creationDate" | cut -d ' ' -f 1)
    
    base=$(basename "$1")
    extension="${base##*.}"
    filename="${base%.*}"


    if [ ! -f  "$dirReport/$owner-$date-$filename.$extension" ]; then
        cp "$1" "$dirReport/$owner-$date-$filename.$extension"
    else
        count=1
        while [ -f "$dirReport/$owner-$date-$filename$count.$extension" ]; do
            count=$((count+1))
        done
        cp "$1" "$dirReport/$owner-$date-$filename$count.$extension"
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
        destination=$(readlink -f $newDestination)
    fi

    echo "$destination"
}

function parseArguments {
	# Reset the getopts internal state
	OPTIND=1
	
    while getopts ":d:b:" opt; do
        case "${opt}" in
            d)
                echo "Option $opt: $OPTARG"
                dirReport="$OPTARG"
                ;;
            b)
                echo "Option $opt: $OPTARG"
                badWords="$OPTARG"
                ;;
            \?)
                #cancelExecution=1
                #print "Requires option"
                log "ERROR: At least 1 valid argument has to be supplied" >&2
                bash
                ;;
            :)
                #cancelExecution=1
                #print "Invalid option"
                log "ERROR: -$OPTARG is not a valid option" >&2
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
	# Check if $1 is not empty
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

	# If there are any arguments, parse them
	if [ $# -gt 0 ]; then
		parseArguments "$@"
	fi

    exists=$(dirReportExists "$dirReport")

    # If dirReport is empty, create it else check if it is a directory
    if [ "$dirReport" == "" ]; then
        dirReport=$(createArchiveFolder)
    elif [ "$exists" == 0 ]; then
        log "ERROR: '$dirReport' is not an existing directory"
        bash
    fi

    readBadWords "$badWords"
    configured=1
}

function debugVars {
    echo "dirReport: $dirReport"
    echo "badWords:"
    for word in "${badWordsArray[@]}"; do
        echo "$word"
    done
}

function runBB()
{
    if [ $configured -eq 0 ]; then
        echo "ERROR: configureBB has not been run" >&2
		log "ERROR: configureBB has not been run"
        bash
    fi

    # Loop through all files in the current working directory
    find . -type f -print0 | while IFS= read -r -d '' file; do
        if [[ "$file" == *$dirReport* ]]; then
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
                        copyToArchive "$file"
                        break
                    fi
                done
            fi
        fi
    done   
}

# init "$@"
# stat -c '%w' file

