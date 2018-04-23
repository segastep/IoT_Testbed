#!/bin/bash

##################################################
### This script will detect the external volumes##
### attached to an instance and build usable    ##
### partitions out of it.                       ##
##################################################

## This script is very specific to our current,
## environment !!!

#This will return the volume name. e.g /dev/sdb
VOLUME_NAME=`sudo fdisk -l | awk '/\/dev\/vd[b-z]/ {print $2}' | awk '{sub(/\:$/,"")}1'`
echo $VOLUME_NAME
PARTITION_TYPE="xfs" #Default type for new partition
echo $PARTITION_TYPE
DEFAULT_MOUNTPOINT="/ext"
echo $DEFAULT_MOUNTPOINT
##sudo fdisk -l | awk '/\/dev\/vd[b-z]/ {print $2}' | awk '{sub(/\:$/,"")}1

##Create partitions
sudo fdisk ${VOLUME_NAME} <<EOF
n
p
1


w
EOF

PARTITION_NAME=`sudo fdisk -l | grep -o '^/dev/vd[b-z][0-9]'`
echo $PARTITION_NAME

sudo mkfs.${PARTITION_TYPE} ${PARTITION_NAME}

##Make mount point
sudo mkdir ${DEFAULT_MOUNTPOINT}
sudo mount ${PARTITION_NAME} ${DEFAULT_MOUNTPOINT}
##Automatically mount on startup
echo "${PARTITION_NAME} ${DEFAULT_MOUNTPOINT} ${PARTITION_TYPE} defaults 0 0" >> /etc/fstab
#RW permission to all users
chmod -R ugo+rw ${DEFAULT_MOUNTPOINT}
