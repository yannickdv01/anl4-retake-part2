#!/bin/bash
set -Eeuxo pipefail

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
    #make array of dirreport and badwords
    
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

    #return array of badwords
    return "${badWordsArray[@]}"

    echo "${badWordsArray[@]}"
}

function init {  
    read -r dirReport badWords < <(parseArguments "$@")
    exists=$(dirReportExists "$dirReport")
    
    if [ ! "$dirReport" == "" ]; then
        if [ "$exists" == 0 ]; then
            echo "ERROR: '$dirReport' is not an existing directory"
        fi
    else
        dirReport=$(createArchiveFolder)
    fi

    saveSettings dirReport badWords
}

#save the settings to a conf file	
function saveSettings {
    #save the settings to a conf  file
    #check if settings file exists in home directory if not create it and write the settings to it. Else just write the settings to it.
    if [ ! -f "$HOME/.config/configureBB.conf" ]; then
        # Check if the .config directory exists, if not create it.
        if [ ! -d "$HOME/.config" ]; then
            mkdir -p "$HOME/.config"
        fi
        
        # create the file
        touch "$HOME/.config/configureBB.conf"
    fi

    tempBadWords=$(readBadWords "$badWords")
    
    # write the settings to the file
    echo "dirReport=$dirReport" > "$HOME/.config/configureBB.conf"
    echo "badWords=$tempBadWords" >> "$HOME/.config/configureBB.conf"
}

init "$@"