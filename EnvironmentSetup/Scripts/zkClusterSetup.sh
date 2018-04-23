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
server.3=${REMOTE_TWO}:2890:3891
EOL


PID_CONTENT=1
create_pid_file()
{

   OUT="/ext/data/myid"
   if [ ! -f "$OUT" ]; then
      mkdir -p "`dirname \"$OUT\"`" 2>/dev/null
   fi
   echo $1 >> $OUT

}

create_pid_file 1
mkdir $ZK_LOGS
#Service setup
############################################

#Create service file
SERVICE_FILE="/etc/systemd/system/zookeeper.service"
sudo cat > ${SERVICE_FILE} <<EOL
[Unit]
Description=Apache Zookeeper server
Documentation=http://zookeeper.apache.org
Requires=network.target remote-fs.target
After=network.target remote-fs.target

[Service]
Type=forking
User=zookeeper
Group=zookeeper
ExecStart=/ext/zookeeper/bin/zkServer.sh start
ExecStop=/ext/zookeeper/bin/zkServer.sh stop
ExecReload=/ext/zookeeper/bin/zkServer.sh restart
WorkingDirectory=/ext/data/logs

[Install]
WantedBy=multi-user.target
EOL

#Setup user and ownership for Service
service_setup()
{
  sudo useradd zookeeper
  sudo chown -R zookeeper. $1
  sudo chown -R zookeeper. $1
  sudo chown -R zookeeper. $2
}

#Some useful stuff for remote calls
ZK_SERVICE_FNAME="$(basename "${SERVICE_FILE}")"
ZK_SERVICE_DESTINATION="$(dirname "${SERVICE_FILE}")"
SETUP_SERVICE_CMD="$(typeset -f service_setup); service_setup ${DATA_DIR} ${ZK_DATA} | base64 -d"

for HOST in $REMOTE_ONE $REMOTE_TWO; do
  HOST_CONNECT="centos@${HOST}"
  DESTINATION="${HOST_CONNECT}:/ext/"
  echo $HOST_CONNECT
  echo $SSH_PK
  echo $DESTINATION
  echo "data dir $DATA_DIR"
  rsync -az -e "ssh \"-o StrictHostKeyChecking=no\" -i ${SSH_PK}" $DATA_DIR $DESTINATION
  ((PID_CONTENT++))
  # Defined here as we increment the PID content on each iter
  COMMAND="$(typeset -f create_pid_file); create_pid_file ${PID_CONTENT} | base64 -d | sudo bash"
  #ssh $HOST_CONNECT "$(typeset -f create_pid_file); create_pid_file"
  ssh $HOST_CONNECT "$COMMAND"
  ssh $HOST_CONNECT "sudo mkdir $ZK_LOGS"
  rsync -az -e "ssh \"-o StrictHostKeyChecking=no\" -i ${SSH_PK}" --rsync-path="sudo rsync" $SERVICE_FILE ${HOST_CONNECT}:${ZK_SERVICE_DESTINATION}
  ssh $HOST_CONNECT "$SETUP_SERVICE_CMD"
  ssh $HOST_CONNECT "sudo systemctl daemon-reload"
  if ssh $HOST_CONNECT "sudo systemctl enable ${ZK_SERVICE_FNAME}" < /dev/null; then
    echo "Started zookeeper service on host:${HOST} exit code: $?"
  else
    echo "Failed to start zookeeper on host:${HOST}, please check previous output to see what went wrong!\nExit code:$?"
    exit $?
  fi
done

##Setup service locally
service_setup ${DATA_DIR} ${ZK_DATA}
systemctl daemon-reload
if systemctl enable ${ZK_SERVICE_FNAME} < /dev/null; then
  echo "Started zookeeper service locally, exit code: $?"
else
  echo "Failed to start zookeeper locally, please check previous output to see what went wrong!\nExit code:$?"
  exit 1
fi
