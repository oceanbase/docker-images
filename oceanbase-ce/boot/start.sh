#!/bin/bash

function is_true() {
  value=$1
  value=${value^^}
  if [ "x${value}" == "xNO" ] || [ "x${value}" == "xFALSE" ] || [ "x${value}" == "x0" ]; then
    return 1
  fi
  return 0
}

function get_mode() {
  if test -z ${MODE}
  then
    MODE="MINI"
  fi
  MODE=${MODE^^}
}

function exit_while_error() {
  if test -z ${EXIT_WHILE_ERROR}
  then
    return 0
  fi

  return `is_true ${EXIT_WHILE_ERROR}`
}

function remove_disk_check_logic_in_obd() {
  # make sure obd copy the plugin code
  obd cluster list
  start_check_files=('/root/.obd/plugins/oceanbase/3.1.0/start_check.py' '/root/.obd/plugins/oceanbase/4.0.0.0/start_check.py')
  for start_check_file in ${start_check_files[@]}
  do
    sed -i "s/critical('(%s) %s not enough disk space\. (Avail/alert('(%s) %s not enough disk space\. (Avail/g" $start_check_file
    sed -i "s/critical(EC_OBSERVER_NOT_ENOUGH_DISK_4_CLOG/alert(EC_OBSERVER_NOT_ENOUGH_DISK_4_CLOG/g" $start_check_file
  done
}

function exec_tenant_init_sql {
  INIT_SCRIPTS_ROOT="${1}";

  # Check whether parameter has been passed on
  if [ -z "${INIT_SCRIPTS_ROOT}" ]; then
    echo "No INIT_SCRIPTS_ROOT passed on, no scripts will be run.";
    return;
  fi;

  # Execute custom provided files (only if directory exists and has files in it)
  if [ -d "${INIT_SCRIPTS_ROOT}" ] && [ -n "$(ls -A "${INIT_SCRIPTS_ROOT}")" ]; then
    echo -e "Executing user defined scripts..."
    run_custom_scripts_recursive ${INIT_SCRIPTS_ROOT}
    echo -e "DONE: Executing user defined scripts.\n"
  fi;
}

function run_custom_scripts_recursive {
  local f
  for f in "${1}"/*; do
    echo -e "running ${f} ...";
    obclient -h127.1 -uroot@${OB_TENANT_NAME} -A -P2881 < ${f}
    echo "DONE: running ${f}";
  done
}

function deploy_failed {
  echo "boot failed!"
  if exit_while_error
  then
    exit 1
  else
    echo "Please check the log file /root/ob/log/observer.log"
  fi
}

function loop_forever() {
    while :; do
        sleep 10
    done
}

function fastboot() {
    cd /root/demo/ && tar -xvzf store.tar.gz
    obd cluster start demo
}

function boot() {
    # generate config based on variables
    envsubst < templates/observer-template.yaml > /tmp/config.yaml
    envsubst < templates/obagent-template.yaml >> /tmp/config.yaml
    envsubst < templates/ob-configserver-template.yaml >> /tmp/config.yaml
    obd cluster deploy obcluster -c /tmp/config.yaml
    if [ $? -ne 0 ]; then
      deploy_failed
    fi
    obd cluster start obcluster
    if [ $? -ne 0 ]; then
      deploy_failed
    fi
}

function create_tenant() {
    create_tenant_cmd="obd cluster tenant create ${OB_CLUSTER_NAME} -n ${OB_TENANT_NAME} -o ${OB_SCENARIO}"
    if ! [ -z "${OB_TENANT_MIN_CPU}" ]; then
      create_tenant_cmd="${create_tenant_cmd} --min-cpu=${OB_TENANT_MIN_CPU}"
    fi;
    if ! [ -z "${OB_TENANT_MEMORY_SIZE}" ]; then
      create_tenant_cmd="${create_tenant_cmd} --memory-size=${OB_TENANT_MEMORY_SIZE}"
    fi;
    if ! [ -z "${OB_TENANT_LOG_DISK_SIZE}" ]; then
      create_tenant_cmd="${create_tenant_cmd} --log-disk-size=${OB_TENANT_LOG_DISK_SIZE}"
    fi;
    eval ${create_tenant_cmd}
    if [ $? -ne 0 ]; then
      deploy_failed
    fi
}

function set_tenant_password() {
    if ! [ -z "${OB_TENANT_PASSWORD}" ]; then
      echo "set tenant password"
      obclient -h127.1 -uroot@${OB_TENANT_NAME} -A -P2881 -e "alter user root identified by '${OB_TENANT_PASSWORD}'"
    fi;
}

# load environment variables
source boot/env.sh

get_mode
remove_disk_check_logic_in_obd
cd /root/.obd && tar -xvzf repository.tar.gz && cd /root
if [ -f "/root/.obd/cluster/obcluster/config.yaml" ]; then
  echo "find obd deploy information, skip configuring..."
  echo "start ob cluster ..."
  obd cluster start obcluster
elif [ "x${MODE}" == "xSLIM" ]; then
  echo "do fastboot for SLIM mode"
  fastboot
else
  echo "do normal boot"
  boot
  create_tenant
fi

sleep 3
exec_tenant_init_sql ${OB_TENANT_INIT_SQL_DIR}
set_tenant_password

echo "boot success!"
loop_forever
