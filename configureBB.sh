#!/bin/bash

function createArchiveFolder {
    destination="./Archive"
    if [ ! -d "$destination" ]; then
        mkdir -p "$destination";
    else
        count=1
        newDestination="$destination"
        while [ -d "$newDestination" ]; do
            newDestination="$destination$count"
            count=$((count+1))
        done

        destination=$newDestination

        mkdir -p "$destination"
    fi
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

function init {
    
    read -r dirReport badWords < <(parseArguments "$@")
    exists=$(dirReportExists "$dirReport")
    
    if [ ! $dirReport == "" ]; then
        if [ $exists == 0 ]; then
            echo "ERROR: '$dirReport' is not an existing directory"
        fi
    else
        createArchiveFolder
    fi  
}

init "$@"