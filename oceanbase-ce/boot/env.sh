export MODE=${MODE:-MINI}
export EXIT_WHILE_ERROR=${EXIT_WHILE_ERROR:-true}
export OB_SERVER_IP=${OB_SERVER_IP:-$(hostname -i)}
export OB_CLUSTER_NAME=${OB_CLUSTER_NAME:-obcluster}

if [ "x${MODE^^}" == "xMINI" ]; then
    export OB_MEMORY_LIMIT=${OB_MEMORY_LIMIT:-6G}
    export OB_SYSTEM_MEMORY=${OB_SYSTEM_MEMORY:-1G}
    export OB_DATAFILE_SIZE=${OB_DATAFILE_SIZE:-5G}
    export OB_LOG_DISK_SIZE=${OB_LOG_DISK_SIZE:-5G}
    export OB_SCENARIO=${OB_SCENARIO:-express_oltp}
else 
    export OB_DATAFILE_SIZE=${OB_DATAFILE_SIZE:-20G}
    export OB_LOG_DISK_SIZE=${OB_LOG_DISK_SIZE:-20G}
    export OB_SCENARIO=${OB_SCENARIO:-htap}
fi


export OB_TENANT_NAME=${OB_TENANT_NAME:-test}
export OB_TENANT_INIT_SQL_DIR=${OB_TENANT_INIT_SQL_DIR:-/root/boot/init.d}

export TELEMETRY_REPORTER="docker_${OB_CLUSTER_NAME}"

if [ -n "$OB_CONFIGSERVER_ADDRESS" ]; then
    export OB_CONFIGURL="${OB_CONFIGSERVER_ADDRESS}/services"
fi
