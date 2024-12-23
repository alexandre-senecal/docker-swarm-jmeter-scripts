# docker-swarm-jmeter-scripts
Bash scripts to facilitate running distributed JMeter through Docker Swarm.

## Swarm Setup
Some helper scripts are provided to initialize the Swarm. 

   1. Set the IP of the manager node you want to advertise and the IPs of the worker VMs in [swarm/swarm_vars.sh](swarm/swarm_vars.sh). 
   2. Now on the manager VM run [swarm/swarm_init.sh](swarm/swarm_init.sh). This will create the swarm, join the nodes and tag then as workers and create the Docker network.

## Run
Use [bin/run.sh](bin/run.sh) to start a distributed run.

Usage

```
./run.sh
Missing command
usage:
Commands:
   run                   Run a distributed test across worker nodes.
      -p projectName     Project name, used to identify and group artifacts by project.
      -i imageName       Docker image name.
      -j jmxFile         The JMeter test file to run.
      -s scale           Optional, number of workers to use. Defaults to all workers.
      -k keep services   Optional, keeps worker services, enables verifying worker logs.

   stop                  Stop a running distributed test.

      -h                 Display this help message.
```
   
## References
   1. [https://docs.docker.com/engine/swarm/](https://docs.docker.com/engine/swarm/)