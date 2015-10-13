#!/bin/bash

USER=$1
IP=$2

ssh -i .chef/keys/$USER@postgresql-bdr-cluster -N -f -R localhost:8889:localhost:8889 -o StrictHostKeyChecking=no ec2-user@$IP <&- >&- 2>&- &
PID=$!
echo $PID > .pid
exit 0
