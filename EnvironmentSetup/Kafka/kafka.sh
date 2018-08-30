#!/bin/bash

# Licence: GPLv3, MIT, BSD, Apache or whatever you prefer; FREE to use, modify, copy, no obligations
# Description: Bash Script to Start Kafka as Daemon on unit system
# Author: Andrew Bikadorov
# Script v0.4

# For debugging purposes uncomment next line
#set -x

APP_NAME="kafkaServer"
APP_PATH="/ext/kafka/"
APP_PID="/var/run/kafka.pid" # kafka-run-class.sh need to be hacked :(

# Should Not Be altered
TMP_FILE="/tmp/status_$APP_NAME"


# Start
start() {
    checkpid
        STATUS=$?
        if [ $STATUS -ne 0 ] ;
    then
                #echo "Starting $APP_NAME..."
                #echo "rm -rf "$log.dirs"/ "
                cd $APP_PATH
                $APP_PATH/bin/kafka-run-class.sh -daemon -name $APP_NAME -loggc kafka.Kafka config/server.properties
                #bin/kafka-server-start.sh -daemon config/server.properties
                # Get PID from running processes
                ps ax | grep -i 'kafka\.Kafka' | grep java | grep -v grep | awk '{print $1}' > $APP_PID
                #echo PID file `cat $APP_PID`
                #statusit
    else
                echo "$APP_NAME Already Running"
    fi
}

# Stop
stop() {
    checkpid
        STATUS=$?
        if [ $STATUS -eq 0 ] ;
        then
                #echo "Stopping $APP_NAME..."
                kill `cat $APP_PID`
                rm $APP_PID
                #statusit
        else
                echo "$APP_NAME - Already killed"
        fi
}

# Status
checkpid(){
    STATUS=9

    if [ -f $APP_PID -a -s $APP_PID ] ; # AND NOT -s $APP_PID OR `cat $APP_PID` == 0
        then
                #echo "Is Running if you can see next line with $APP_NAME"
                #ps -Fp `cat $APP_PID` | grep -i 'kafka\.Kafka' > $TMP_FILE
                ps ax | grep -i 'kafka\.Kafka' > $TMP_FILE
                if [ -f $TMP_FILE -a -s $TMP_FILE ] ;
                        then
                                STATUS=0
                                #"Is Running (PID `cat $APP_PID`)"
                        else
                                STATUS=2
                                #"Stopped incorrectly"
                        fi

                ## Clean after yourself
                rm -f $TMP_FILE
        else
                STATUS=1
                #"Not Running"
        fi

        return $STATUS
}


statusit() {
    checkpid
    #GET return value from previous function
        STATUS=$?

        case $STATUS in
                0)
                        EXITSTATUS="Is Running"
                        ;;
                1)
                        EXITSTATUS="Not Running"
                        ;;
                2)
                        EXITSTATUS="Stopped incorrectly"
                        ;;
                *)

                $EXITSTATUS="Default Status (should not be seen)"
                ;;
        esac

    echo $APP_NAME - $EXITSTATUS
}


## What option to run
case "$1" in
    'start')
        start
        ;;
    'stop')
        stop
        ;;
    'restart')
        stop
        start
        ;;
    'status')
        statusit
        ;;
    *)
        echo "Usage: $0 { start | stop | restart | status }"
        exit 1
        ;;
esac

exit 0
