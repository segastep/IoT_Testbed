#!/bin/bash

#############################################################################
##  This script is to be run on a Node which will be master for            ##
##  Flink cluster script is used to configure the master and TWO slaves!   ##
##  This verion of the script does not is working only if java is present  ##
##  on all the slaves                                                      ##
## For this script to work you will need Georgi-PM PK                      ##
############################################################################

# Full path of this script
THIS=`readlink -f "${BASH_SOURCE[0]}" 2>/dev/null||echo $0`

# This directory path
DIR=`dirname "${THIS}"`

function usage_and_exit()
{
    echo "$0 -f <slave one ip> -s <slave two ip> -k path to private key used to ssh into slaves"
    exit
}

while getopts f:s:k: flag
do
    case $flag in
        f)
            SLAVE_ONE=$OPTARG;;
        s)
            SLAVE_TWO=$OPTARG;;
        k)
            SSH_PK=$OPTARG;;
        ?)
            usage_and_exit;;
      esac
done

if [[ -z "$SLAVE_ONE" || -z "$SLAVE_TWO" || -z "$SSH_PK" ]];
then
    echo "Missing a required parameter (slave one ip and slave two ip are required)"
    usage_and_exit
fi

if [ ! -f "$SSH_PK" ]
then
    echo "$0: File '${SSH_PK}' not found. Cannot proceed without private key."
    exit 1;
fi

printf "Flink slave one ip set to: %s\nFlink slave two ip set to: %s\n" "$SLAVE_ONE" "$SLAVE_TWO"
printf "Using private key %s\n" "$SSH_PK"
printf "Checking if java 8 is installed......\n"

###########################################
####CHECK JAVA INSTALLATION################
##########################################

# Minimal version
MINIMAL_VERSION=1.8.0

# Check if Java is present and the minimal version requirement
_java=`type java | awk '{ print $ NF }'`
CURRENT_VERSION=`"$_java" -version 2>&1 | awk -F'"' '/version/ {print $2}'` #says 1.8.0_65
minimal_version=`echo $MINIMAL_VERSION | awk -F'.' '{ print $2 }'` #says 8
current_version=`echo $CURRENT_VERSION | awk -F'.' '{ print $2 }'` #says 8

if [ $current_version ]; then
  if [ $current_version -lt $minimal_version ]; then
    echo "Error: Java version is too low. At least Java >= ${MINIMAL_VERSION} needed. Fix java version and run script";
    exit 1;
  fi
    else
      echo "Not able to find Java executable or version. Attempting to install Java 8";
      . "$DIR/java.sh"
      eval "$DIR/java.sh"
      if [ $? -eq 0 ]
        then
          echo "Successfully installed Java 8"
        else
          echo "Error: Attempted to install Java 8 but failed, install java manually and re run script" >&2
          exit 1;
      fi
fi

################################################################################
#######################BEGIN FLINK INSTALLATION#################################
################################################################################

#FLINK_KEY="/home/centos/.ssh/flink.key"
#PUB="${FLINK_KEY}.pub"
#AUTHORIZED_KEYS_LOCAL="/home/centos/.ssh/authorized_keys"

#ssh-keygen -t rsa -N "" -f $FLINK_KEY
#cat $PUB >>  $AUTHORIZED_KEYS_LOCAL

#Build slaves hostnames
USER="centos@"
SLAVE_ONE_ADDRESS=$USER$SLAVE_ONE
SLAVE_TWO_ADDRESS=$USER$SLAVE_TWO

#Download FLINK_HADOOP to master
FLINK_URL="https://archive.apache.org/dist/flink/flink-1.4.1/flink-1.4.1-bin-hadoop24-scala_2.11.tgz"
FLINK="flink-1.4.1-bin-hadoop24-scala_2.11.tgz"
FLINK_INSTALL_DIR="flink-0.10.1"
FLINK_ARCHIVE="/home/centos/"
CURR_DIRR=`pwd`
cd $FLINK_ARCHIVE && { curl -O ${FLINK_URL} ; cd -; }

eval `ssh-agent -s`
ssh-add ${SSH_PK}

#Copy FLINK to SLAVES
rsync -avz -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" --progress ${FLINK} ${SLAVE_ONE_ADDRESS}:${FLINK_ARCHIVE}
if [ $? -eq 0 ]
  then
    echo "Successfully copied Flink source to $SLAVE_ONE_ADDRESS"
  else
    echo "Error: Failed to copy Flink to $SLAVE_ONE_ADDRESS" >&2
    exit 1;
fi

rsync -avz -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" --progress ${FLINK} ${SLAVE_TWO_ADDRESS}:${FLINK_ARCHIVE}
if [ $? -eq 0 ]
  then
    echo "Successfully copied Flink source to $SLAVE_TWO_ADDRESS"
  else
    echo "Error: Failed to copy Flink to $SLAVE_TWO_ADDRESS" >&2
    exit 1;
fi

tar -xvzf ${FLINK} -C /opt/
rc=$?; if [[ $rc != 0 ]];
then
echo "Failed to extract flink on master."
exit $rc; fi

#cat myfile.tgz | ssh user@host "tar xzf - -C /some/dir"
cat ${FLINK_ARCHIVE}${FLINK} | ssh ${SLAVE_ONE_ADDRESS} "sudo tar xzf - -C /opt/"
rc=$?; if [[ $rc != 0 ]];
then
echo "Failed to extract flink on slave ${SLAVE_ONE_ADDRESS}."
exit $rc; fi

cat ${FLINK_ARCHIVE}${FLINK} | ssh ${SLAVE_TWO_ADDRESS} "sudo tar xzf - -C /opt/"
rc=$?; if [[ $rc != 0 ]];
then
echo "Failed to extract flink on slave ${SLAVE_TWO_ADDRESS}."
exit $rc; fi

#TO DO CONFIGURATION ON MASTER
