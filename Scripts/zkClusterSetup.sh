#!/bin/bash
##########################################################
# Script is used to set up three node zookeeper cluster.##
# Private Key file required for ssh calls               ##
###########################################################

# Full path of this script
THIS=`readlink -f "${BASH_SOURCE[0]}" 2>/dev/null||echo $0`

# This directory path
DIR=`dirname "${THIS}"`

function usage_and_exit()
{
    echo "$0 -f <virtual ip of this machine> -s <second instance ip> -m <thir dinstance ip> -k <path to private key used to ssh into instances>"
    exit
}

while getopts f:s:k:m: flag
do
    case $flag in
        f)
            LOCAL=$OPTARG;;
        s)
            REMOTE_ONE=$OPTARG;;
        m)
            REMOTE_TWO=$OPTARG;;
        k)
            SSH_PK=$OPTARG;;
        ?)
            usage_and_exit;;
      esac
done

if [[ -z "$LOCAL" || -z "$REMOTE_ONE" || -z "$REMOTE_TWO" ]];
then
    echo "Missing a required parameter (slave one ip and slave two ip are required)"
    usage_and_exit
fi

if [ ! -f "$SSH_PK" ]
then
    echo "$0: File '${SSH_PK}' not found. Cannot proceed without private key."
    exit 1;
fi

#Deal with private ssh keys
AUTHORIZED_KEYS_LOCAL="/home/centos/.ssh/authorized_keys"
SSH_CONFIG="/home/centos/.ssh/config"
eval `ssh-agent -s`
ssh-add ${SSH_PK}
echo "IdentityFile ${SSH_PK}" > ${SSH_CONFIG}
sudo chmod 600 ${SSH_CONFIG}

#Build slaves hostnames
USER="centos@"
SLAVE_ONE_ADDRESS=$USER$REMOTE_ONE
SLAVE_TWO_ADDRESS=$USER$REMOTE_TWO

#for SLAVE in $SLAVE_ONE_ADDRESS $SLAVE_TWO_ADDRESS; do
#  scp $PUB $SLAVE://home/centos/.ssh
#  scp $AUTHORIZED_KEYS_LOCAL $SLAVE://home/centos/.ssh
#done

HOSTS_FILE="/etc/hosts"

#External hard drive dir
EXT="/ext"
DATA_DIR="$EXT/zookeeper"
ZK_DATA="$EXT/data/"
ZK_LOGS="$EXT/data/logs"
ZK_CONF_FILE="$DATA_DIR/conf/zoo.cfg"

cd $EXT
wget http://mirror.downloadvn.com/apache/zookeeper/stable/zookeeper-3.4.10.tar.gz
tar -xzf zookeeper-3.*
sudo rm zookeeper-3.4.10.tar.gz
sudo mv zookeeper* zookeeper

##Build the config File
cat >> ${ZK_CONF_FILE} <<EOL
tickTime=2000
dataDir=${ZK_DATA}
dataLogDir=${ZK_LOGS}
clientPort=2181
initLimit=5
syncLimit=2
server.1=${LOCAL}:2888:3888
server.2=${REMOTE_ONE}:2889:3889
server.2=${REMOTE_TWO}:2890:3891
EOL

PID_CONTENT=1

create_pid_file()
{

   OUT="/ext/data/zookeeper_id"
   if [ ! -f "$OUT" ]; then
      mkdir -p "`dirname \"$OUT\"`" 2>/dev/null
   fi
   echo $PID_CONTENT >> $OUT
   mkdir $ZK_LOGS
}

$(create_pid_file)


for HOST in $REMOTE_ONE $REMOTE_TWO; do
  HOST_CONNECT="centos@${HOST}"
  DESTINATION="${HOST_CONNECT}:/ext/"
  echo $HOST_CONNECT
  echo $SSH_PK
  echo $DESTINATION
  echo "data dir $DATA_DIR"
  rsync -az -e "ssh \"-o StrictHostKeyChecking=no\" -i ${SSH_PK}" $DATA_DIR $DESTINATION
  ((PID_CONTENT++))
  #ssh $HOST_CONNECT "$(typeset -f create_pid_file); create_pid_file"
  sudo bash -c "$(declare -f hello); hello"
  ssh $HOST_CONNECT "$(typeset -f create_pid_file); create_pid_file | base64 -d | sudo bash"
  ssh $HOST_CONNECT "sudo mkdir $ZK_LOGS"

done
