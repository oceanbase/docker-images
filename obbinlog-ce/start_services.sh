#!/bin/bash
set -e

# =============================================================================
# OceanBase Database Container Deployment Script
# =============================================================================
# This script automates the deployment of OceanBase database cluster in Docker
# Supports customizable tenant name and password via environment variables
# =============================================================================

# Step 1: Environment Variables Configuration
# =============================================================================
CLUSTER_NAME=${CLUSTER_NAME:-"ob"}
OBSERVER_PATCHED=${OBSERVER_PATCHED:-"/home/admin/oceanbase/bin/observer"}
OBPROXY_PATCHED=${OBPROXY_PATCHED:-"/home/admin/obproxy/bin/obproxy"}
OBBINLOG_PATCHED=${OBBINLOG_PATCHED:-"/home/ds/oblogproxy/run.sh"}

# Step 2: Port Configuration
# =============================================================================
JDBC_PORT=2881      # Database connection port
RPC_PORT=2882       # Internal communication port
OBPROXY_PORT=2883   # Proxy connection port

# Step 3: Tenant and Password Configuration
# =============================================================================
TENANT_NAME=${TENANT_NAME:-"test"}           # Tenant name (configurable via Docker env)
PASSWORD=${PASSWORD:-"123456"}               # System password (configurable via Docker env)
PASSWORD_SHA1=$(echo -n "$PASSWORD" | sha1sum | cut -d' ' -f1)  # SHA1 hash for OBProxy

# Step 3.1: Storage Configuration
# =============================================================================
DATAFILE_SIZE=${DATAFILE_SIZE:-"5G"}        # Data file size (configurable via Docker env)
LOG_DISK_SIZE=${LOG_DISK_SIZE:-"4G"}        # Log disk size (configurable via Docker env)

# Step 4: Display Configuration Information
# =============================================================================
echo "=== OceanBase Deployment Configuration ==="
echo "Cluster Name: $CLUSTER_NAME"
echo "Observer Path: $OBSERVER_PATCHED"
echo "OBProxy Path: $OBPROXY_PATCHED"
echo "Ports: JDBC=$JDBC_PORT, RPC=$RPC_PORT, Proxy=$OBPROXY_PORT"
echo "Tenant: $TENANT_NAME, Password: $PASSWORD"
echo "Storage: DataFile=$DATAFILE_SIZE, LogDisk=$LOG_DISK_SIZE"
echo "=========================================="

# Step 5: Start OceanBase Configuration Server
# =============================================================================
echo "Starting OceanBase configuration server..."
obd cluster start config-server

# Step 6: Initialize Data Directories
# =============================================================================
echo "Initializing data directories..."
if [ ! -d "/data" ]; then
    mkdir -p "/home/ds" "/data"
fi
chown -R admin:admin /data

# Step 7: OceanBase Observer Initialization and Startup
# =============================================================================
echo "Starting OceanBase Observer service..."
cat <<EOF | su - admin
cd ~

# Set environment variable for cluster name
if ! grep -q "export cluster_name=" .bashrc; then
    echo "export cluster_name='$CLUSTER_NAME'" >> ~/.bashrc
fi
source .bashrc

# Clean up existing data directories
rm -rf /data/1/'$CLUSTER_NAME'
rm -rf /data/log1/'$CLUSTER_NAME'
rm -rf /home/admin/oceanbase/store/'$CLUSTER_NAME'
rm -rf /home/admin/oceanbase/log/* /home/admin/oceanbase/etc/*config*

# Create data directory structure
mkdir -p /data/1/'$CLUSTER_NAME'/{etc3,sstable,slog}
mkdir -p /data/log1/'$CLUSTER_NAME'/{clog,etc2}
mkdir -p /home/admin/oceanbase/store/'$CLUSTER_NAME'

# Create symbolic links for data mapping
ln -s /data/1/'$CLUSTER_NAME'/etc3 /home/admin/oceanbase/store/'$CLUSTER_NAME'/etc3
ln -s /data/1/'$CLUSTER_NAME'/sstable /home/admin/oceanbase/store/'$CLUSTER_NAME'/sstable
ln -s /data/1/'$CLUSTER_NAME'/slog /home/admin/oceanbase/store/'$CLUSTER_NAME'/slog
ln -s /data/log1/'$CLUSTER_NAME'/clog /home/admin/oceanbase/store/'$CLUSTER_NAME'/clog
ln -s /data/log1/'$CLUSTER_NAME'/etc2 /home/admin/oceanbase/store/'$CLUSTER_NAME'/etc2

# Start OceanBase Observer with configuration
cd /home/admin/oceanbase/store/$CLUSTER_NAME/ && $OBSERVER_PATCHED \
    -I 127.0.0.1 \
    -p $JDBC_PORT \
    -P $RPC_PORT \
    -z zone1 \
    -n $CLUSTER_NAME \
    -d /home/admin/oceanbase/store/$CLUSTER_NAME/ \
    -c 1000 \
    -o "memory_limit=6G,__min_full_resource_pool_memory=1073741824,system_memory=1G,datafile_size=$DATAFILE_SIZE,max_syslog_file_count=2,log_disk_size=$LOG_DISK_SIZE,obconfig_url=http://127.0.0.1:8080/services?Action=ObRootServiceInfo&User_ID=alibaba&UID=admin&ObCluster=$CLUSTER_NAME"

EOF

# Step 8: Wait for Observer to Start
# =============================================================================
echo "Waiting for Observer to start..."
echo "Sleeping for 60 seconds to allow Observer to start..."
sleep 60

echo "Checking Observer connection..."
if obclient -h127.0.0.1 -uroot -P $JDBC_PORT -e "SELECT 1;" 2>/dev/null; then
  echo "Observer is ready!"
fi

# Step 9: Initialize OceanBase Cluster and Create Users
# =============================================================================
echo "Initializing OceanBase cluster and creating users..."

#

# Add error handling for cluster initialization
obclient -h127.0.0.1 -uroot -P $JDBC_PORT -A <<EOF
SET SESSION ob_query_timeout=1000000000;
ALTER SYSTEM BOOTSTRAP ZONE "zone1" SERVER "127.0.0.1:${RPC_PORT}";
alter user root identified by "$PASSWORD";
CREATE USER proxyro IDENTIFIED BY "$PASSWORD";
GRANT SELECT ON *.* TO proxyro;

# Create resource unit for tenant
CREATE RESOURCE UNIT unit_cf_min
    MEMORY_SIZE = "2G",
    MAX_CPU = 1, MIN_CPU = 1,
    LOG_DISK_SIZE = "2G",
    MAX_IOPS = 10000, MIN_IOPS = 10000, IOPS_WEIGHT=1;

# Create resource pool
CREATE RESOURCE POOL rs_pool_1
    UNIT="unit_cf_min",
    UNIT_NUM=1,
    ZONE_LIST=("zone1");

# Create tenant
CREATE TENANT IF NOT EXISTS $TENANT_NAME
    PRIMARY_ZONE="zone1",
    RESOURCE_POOL_LIST=("rs_pool_1")
    set OB_TCP_INVITED_NODES="%",
    lower_case_table_names = 1;

EOF

echo "Tenant '$TENANT_NAME' created successfully"

# Step 10: Configure Tenant User Password
# =============================================================================
echo "Configuring tenant user password..."
echo "Setting password for root user in tenant '$TENANT_NAME'..."

# Set password and capture any errors
echo "Executing password set command..."
echo "Command: alter user root identified by '$PASSWORD';"
result=$(obclient -h127.0.0.1 -uroot@$TENANT_NAME -P ${JDBC_PORT} -A -e "alter user root identified by '$PASSWORD';" 2>&1)
echo "Command result: $result"

# Check if password was set successfully
echo "Verifying password was set successfully..."
verify_result=$(obclient -h127.0.0.1 -uroot@$TENANT_NAME -P ${JDBC_PORT} -p$PASSWORD -e "SELECT 1;" 2>&1)
echo "Verification result: $verify_result"
if [ $? -eq 0 ]; then
  echo "✅ Password for tenant '$TENANT_NAME' was set successfully"
else
  echo "❌ Failed to verify password for tenant '$TENANT_NAME'"
fi

# Step 11: Start OBProxy Service
# =============================================================================
echo "Starting OBProxy service..."
cat <<EOF | su - admin
source .bashrc
cd /home/admin/obproxy && $OBPROXY_PATCHED \
    -r "127.0.0.1:$JDBC_PORT" \
    -p $OBPROXY_PORT \
    -o "observer_sys_password=$PASSWORD_SHA1,enable_strict_kernel_release=false,enable_cluster_checkout=false,enable_metadb_used=false,obproxy_config_server_url=http://127.0.0.1:8080/services?Action=GetObProxyConfig&User_ID=alibaba&UID=admin" \
    -c $CLUSTER_NAME
EOF

# Step 12: Install and Configure Binlog Service
# =============================================================================
echo "Installing and configuring binlog service..."

# Check for obbinlog RPM package
rpm_files=$(ls /app/obbinlog-*.rpm 2> /dev/null)

if [ -n "$rpm_files" ]; then
    echo "Installing obbinlog package..."
    rpm -ivh --replacefiles /app/obbinlog-*.rpm
    rm -f /app/obbinlog-*.rpm
fi

sleep 5

# Step 13: Configure Binlog Service
# =============================================================================
echo "Configuring binlog service..."
node_ip=$(hostname -i)
cat <<EOF > /home/ds/oblogproxy/env/deploy.conf.json
{
  "host": "127.0.0.1",
  "node_ip": "$node_ip",
  "port": $OBPROXY_PORT,
  "user": "root@sys",
  "password": "$PASSWORD",
  "database": "",
  "sys_user": "root",
  "sys_password": "$PASSWORD",
  "supervise_start": "false",
  "node_disk_limit_threshold_percent": 95,
  "init_schema": ""
}
EOF

# Step 14: Deploy and Start Binlog Service
# =============================================================================
echo "Deploying binlog service..."
source /etc/profile
cd /home/ds/oblogproxy/env/

sh deploy.sh -m deploy -f deploy.conf.json
sleep 5

# Step 15: Configure OBProxy Binlog Settings
# =============================================================================
echo "Configuring OBProxy binlog settings..."
obclient -h127.0.0.1 -uroot@sys -P$OBPROXY_PORT -A -p$PASSWORD <<EOF
alter proxyconfig set binlog_service_ip="127.0.0.1:2983";
alter proxyconfig set init_sql="set _show_ddl_in_compat_mode = 1;";
EOF

# Step 16: Create Binlog for Tenant
# =============================================================================
sleep 30

echo "=== Starting CREATE BINLOG command ==="
echo "Command: CREATE BINLOG FOR TENANT ${CLUSTER_NAME}.$TENANT_NAME WITH CLUSTER URL \"http://127.0.0.1:8080/services?Action=ObRootServiceInfo&User_ID=alibaba&UID=admin&ObCluster=${CLUSTER_NAME}\""
echo "Timestamp: $(date)"

# Execute CREATE BINLOG with timeout and better error handling
echo "Executing CREATE BINLOG command..."
echo "Note: This command may take some time and could potentially cause issues."
echo "If the command fails, the container will continue running without binlog functionality."

# Apply binlog resource settings quietly
obclient -h127.0.0.1 -uroot@sys -P ${JDBC_PORT} -p$PASSWORD -e "UPDATE binlog_cluster.config_template SET value='false' WHERE key_name='enable_resource_check';" >/dev/null 2>&1
obclient -h127.0.0.1 -uroot@sys -P ${JDBC_PORT} -p$PASSWORD -e "UPDATE binlog_cluster.config_template SET value=95 WHERE key_name='node_disk_limit_threshold_percent';" >/dev/null 2>&1

$OBBINLOG_PATCHED stop >/dev/null 2>&1 || true
sleep 3
$OBBINLOG_PATCHED start >/dev/null 2>&1 || true
sleep 10


# Try to execute CREATE BINLOG; exit on failure
proxyro_result=$(obclient -A -c -h 127.0.0.1 -P2983 -e "CREATE BINLOG FOR TENANT ${CLUSTER_NAME}.$TENANT_NAME WITH CLUSTER URL \"http://127.0.0.1:8080/services?Action=ObRootServiceInfo&User_ID=alibaba&UID=admin&ObCluster=${CLUSTER_NAME}\";" 2>&1)
proxyro_exit_code=$?

echo "执行结果 (退出码: $proxyro_exit_code):"
echo "$proxyro_result"
echo ""

if [ $proxyro_exit_code -ne 0 ]; then
    echo "❌ CREATE BINLOG command failed"
    exit 1
fi

echo "✅ Binlog created successfully for tenant '$TENANT_NAME'"

# Step 17: Keep Container Running
# =============================================================================
echo "OBBinlog is ready!"

# Keep container running quietly
while true; do
  sleep 30
done