#!/bin/bash
set -e

source swarm_vars.sh
source ../bin/perf_vars.sh

for worker_ip in "${WORKER_MACHINE_IPS[@]}"
do
    ssh -t $(logname)@$worker_ip "sudo docker swarm leave -f"
done

docker swarm leave -f

docker network rm $TEST_NET