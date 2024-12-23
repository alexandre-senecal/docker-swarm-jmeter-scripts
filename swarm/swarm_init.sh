#!/bin/bash
set -e

source swarm_vars.sh
source ../bin/perf_vars.sh

# Init docker swarm manager on machine
docker swarm init --advertise-addr $MANAGER_MACHINE_IP

# From swarm manager overlay network creation
docker network create \
  -d overlay \
  --attachable \
  --subnet=$SUB_NET $TEST_NET
  
joinCommand=$(docker swarm join-token worker | grep "docker swarm")

for worker_ip in "${WORKER_MACHINE_IPS[@]}"
do
    workerName=$(ssh -t $(logname)@$worker_ip "sudo $joinCommand && uname -n")
    docker node update --label-add worker=true $workerName
done