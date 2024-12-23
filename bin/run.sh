#!/bin/bash
set -e

source perf_vars.sh

# =========================================
# Start of function Declaration
# =========================================
help(){
    echo "usage:"
    echo "Commands:"
    echo "   run                   Run a distributed test across worker nodes."
    echo "      -p projectName     Project name, used to identify and group artifacts by project."
    echo "      -i imageName       Docker image name."
    echo "      -j jmxFile         The JMeter test file to run."
    echo "      -s scale           Optional, number of workers to use. Defaults to all workers."
    echo "      -k keep services   Optional, keeps worker services, enables verifying worker logs."
    echo ""
    echo "   stop                  Stop a running distributed test."
    echo ""
    echo "      -h                 Display this help message."
}

createWorkerGlobalService (){
    docker service create \
      --replicas=$SCALE \
      --replicas-max-per-node=1 \
      --constraint node.labels.worker==true \
       --name $WORKER_SERVICE_NAME \
       --network $TEST_NET \
       $IMAGE_NAME \
       -s \
       -n \
       -Jclient.rmi.localport=7000 \
       -Jserver.rmi.localport=60000 \
       -Jserver.rmi.ssl.disable=true
}

getWorkerTaskIps(){
   task_ips=()

   # List service tasks, table prints a header so we start loop at second item
   local work_service_tasks
   readarray -t work_service_tasks < <(docker service ps $WORKER_SERVICE_NAME -q)

   for work_service in "${work_service_tasks[@]}"
   do
        local taskIp
        taskIp=$(docker inspect -f '{{range.NetworksAttachments}}{{.Addresses}}{{end}}' ${work_service} | cut -d '/' -f 1 | cut -d '[' -f 2)
      task_ips+=( $taskIp )
   done
}

createManagerService(){
   local timestamp
   timestamp=$(date +%Y%m%d_%H%M%S)

   local jmx_filename
   jmx_filename=${JMX_FILE##*/}

   local jmx_report_name
   jmx_report_name=${jmx_filename%.jmx}

   # Test directories
   local source_test_dir
   source_test_dir=$(realpath $BASE_DIR)
   local target_test_dir=/mnt/jmeter

   # Get worker hostnames to connect
   getWorkerTaskIps

   local report_name=${jmx_report_name}_${timestamp}
   local jtl_file=${LOG_DIR}/$PROJECT/${report_name}.jtl
   local log_file=${LOG_DIR}/$PROJECT/${report_name}.log

   docker run \
       --name $MANAGER_CONTAINER_NAME \
       --rm \
      --network $TEST_NET \
      -v $source_test_dir:$target_test_dir \
      -v $LOG_DIR:$LOG_DIR \
      $IMAGE_NAME \
      -n \
      -Jclient.rmi.localport=7000 \
      -Jserver.rmi.ssl.disable=true \
      -R $(echo $(printf ",%s" "${task_ips[@]}") | cut -c 2-) \
      -t $target_test_dir/$JMX_FILE \
      -l $jtl_file \
      -j $log_file

   report $report_name $log_file $jtl_file

   # Stop services
   if [ -v KEEP_WORKERS ]
   then
      echo "!!!ATTENTION!!! The keep services flag has been set, your service workers will stay up when the test completes."
       echo "Issue the following command to release the services when done, this needs to be completed prior to starting another test."
       echo "docker service rm $WORKER_SERVICE_NAME"
    else
      docker service rm $WORKER_SERVICE_NAME
      echo "Removed service $WORKER_SERVICE_NAME"
   fi
}

report(){
   local report_name=$1
   local log_file=$2
   local jtl_file=$3

   local report=$REPORT_DIR/$PROJECT/$report_name
   mkdir -p $report

   echo "Generating report: $report_name"

   docker run \
       --name jmeter_report \
       --rm \
      -v $LOG_DIR:$LOG_DIR \
      -v $REPORT_DIR:/mnt/report \
      $IMAGE_NAME \
       -g $jtl_file \
       -o /mnt/report/$PROJECT/$report_name

   echo "Report Generated, see"
   echo "$REPORT_DIR/$PROJECT/$report_name"

    # Move jtl file into report folder
    mv $jtl_file $report

   # Move log into report folder
   mv $log_file $report
}

runExecution(){
    if [ -z ${PROJECT+x} ]; then
        echo "Missing -p projectName"
        missingVar=true
    fi

    if [ -z ${IMAGE_NAME+x} ]; then
        echo "Missing -i imageName"
        missingVar=true
    fi

    if [ -z ${JMX_FILE+x} ] || [ ! ${JMX_FILE: -4} == ".jmx" ] || [ ! -f $JMX_FILE ]; then
        echo "Missing -j jmxFile,check your file paths and ensure it uses extension .jmx"
        missingVar=true
    fi

    readonly SCALE=$(docker node ls --filter node.label=worker=true --format {{.ID}} | wc -l)
   if [ ! -z ${USER_SCALE+x} ] && [ $USER_SCALE -gt $SCALE ]
   then
      echo "Scale value is greater than the number of worker nodes ${USER_SCALE}/$(($SCALE)), you need more machines!"
        missingVar=true
   fi

    if [ ! -z ${missingVar+x} ]; then
        help
        exit 1
    fi

   # create services
   createWorkerGlobalService
   createManagerService
}

stopExecution(){
   docker stop $MANAGER_CONTAINER_NAME || true
   docker service rm $WORKER_SERVICE_NAME
}

# =========================================
# End of function Declaration
# =========================================

# Parse options to the `pip` command
while getopts ":p:i:j:r:s:hk:" opt; do
  case ${opt} in
   p)
      readonly PROJECT=$OPTARG
        readonly MANAGER_CONTAINER_NAME=jmeter_manager_${PROJECT}
        readonly WORKER_SERVICE_NAME=jmeter_workers_${PROJECT};;
   i)
      IMAGE_NAME=$OPTARG
        readonly IMAGE_NAME;;
   j)
      JMX_FILE=$OPTARG
      readonly JMX_FILE;;
   s)
      USER_SCALE=$OPTARG
        readonly USER_SCALE;;
   h)
      help
      exit 0;;
   k)
       KEEP_WORKERS=true
       readonly KEEP_WORKERS;;
   \?)
        echo "Invalid Option: -$OPTARG" 1>&2
      help
      exit 1;;
   :) 
       echo "Missing option argument for -$OPTARG" >&2; exit 1;;
   *) 
       echo "Unimplemented option: -$OPTARG" >&2; exit 1;;
  esac
done

# Shift to non option args
shift "$((OPTIND-1))"
case "$1" in
   run)
      runExecution
      ;;
   stop)
      stopExecution
      ;;
   *)
      echo "Missing command"
      help
      exit 1;;
esac