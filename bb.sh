#!/bin/bash
set -Eeuxo pipefail

dirReport="./Archive"
badWordsArray=()
configured=false

function log() {
    # Check if we have a log file in the home directory
    if [ -f "$HOME/log.txt" ]; then
        echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] $1" >> "$HOME/log.txt"
    else
        echo "[$(date +%Y-%m-%dT%H:%M:%S%z)] $1" > "$HOME/log.txt"
    fi
}

function copyToArchive {
    owner=$(stat -c '%U' "$1")

    creationDate=$(stat -c '%w' "$1")

    # If creation date is not set or is "-" log error
    if [ -z "$creationDate" ] || [ "$creationDate" == "-" ]; then
        log "Error: Creation date is not set for $1, the current filesystem may not support this feature."
        echo "There was a non critical error during execution of the script. Please check the log file for more information."

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

#todo 1 - check if the file is a text file ✔
#todo 2 - runBB ✅✔️✅✔️
#todo 3 - copy file to archive folder, rename with (user)-(creation date(year-month-day))-(original-file-name(count)).(extension) ✔
#todo 4 - error handling
#todo 5 - check if configureBB is run correctly ✔


function createArchiveFolder {
    destination="./Archive"
    if [ ! -d "$destination" ]; then
        mkdir -p "$destination"

        # Save the absolute path of the folder
        destination=$(cd "$destination" && pwd)
        cd ..
    else
        count=1
        newDestination="$destination"
        while [ -d "$newDestination" ]; do
            newDestination="$destination$count"
            count=$((count+1))
        done

        destination=$newDestination

        mkdir -p "$destination"

        # Save the absolute path of the folder
        destination=$(cd "$destination" && pwd)
        cd ..
    fi

    echo "$destination"
}

function parseArguments {
    while getopts "d:b:" opt; do
        case $opt in
            d)
                dirReport="$OPTARG"
                ;;
            b)
                badWords="$OPTARG"
                ;;
            \?)
                #print to stderr
                echo "ERROR: -$OPTARG is not a valid option"
                exit 1
                ;;
            :)
                echo "ERROR: -$OPTARG requires an argument"
                exit 1
                ;;
        esac
    done
    
    echo "$dirReport $badWords"
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
    #check if badwords file exists
    if [ -f "$1" ]; then
        #if badwords file exists, check if badwords file is empty
        if [ -s "$1" ]; then
            #if badwords file is not empty, read badwords file and create array of badwords
            while read -r line; do
                badWordsArray+=("$line")
            done < "$1"
        else
            #if bardwords file is empty, set default badwords
            badWordsArray=("bad")
        fi
    else
        # if badwords file does not exist, print error message and exit
        echo "ERROR: badwords file does not exist"
        exit 1
    fi
}

function configureBB {  
    read -r dirReport badWords < <(parseArguments "$@")
    
    exists=$(dirReportExists "$dirReport")

    # If dirReport is not set to "./Archive", create the folder
    if [ ! "$dirReport" == "./Archive" ]; then
        if [ "$exists" == 0 ]; then
            echo "ERROR: '$dirReport' is not an existing directory"
            exit 1
        fi
    # If dirreport is set to "./Archive" or empty, set dirreport to default value
    elif [ "$dirReport" == "./Archive" ] || [ "$dirReport" == "" ]; then
        dirReport=$(createArchiveFolder)
    fi

    readBadWords "$badWords"

    configured=true
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
    if [ "$configured" == false ]; then
        echo "ERROR: configureBB has not been run"
        exit 1
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

