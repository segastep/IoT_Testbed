#All scripts to transfer are in top directory
#Private key must be added to ssh-agent for This
# script to work
REMOTE_HOSTS="$(cat $(pwd)/remote_hosts.txt)"
TOP_DIR="$(dirname "$(pwd)")"
PK_LOCATION="/path/to/private/key"
cd $TOP_DIR

for FILE in *.sh ; do
  echo "Current file: $FILE"
  for SERVER in $REMOTE_HOSTS; do
    echo "Trying to copy ${FILE} to ${SERVER}"
    rsync -avz -e "ssh \"-o StrictHostKeyChecking=no\" -i ${PK_LOCATION}" $FILE $SERVER:~
  done
done
