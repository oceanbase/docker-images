#!/bin/bash
set -e

# =============================================================================
# OceanBase Database Environment Configuration Script
# =============================================================================
# This script configures the environment for OceanBase database deployment
# Includes user creation, package installation, and environment setup
# =============================================================================

# Step 1: Load OceanBase Environment Variables
# =============================================================================
echo "Loading OceanBase environment variables..."
source /etc/profile.d/obd.sh

# Step 2: Configure and Deploy OceanBase Configuration Server
# =============================================================================
echo "Configuring OceanBase configuration server..."

# Create configuration file for OceanBase config server
cat > ob-config.yaml <<EOF
ob-configserver:
  servers:
    - 127.0.0.1
  global:
    listen_port: 8080
    server_ip: 0.0.0.0
    home_path: /home/admin/ob-configserver
EOF

# Deploy the configuration server
obd cluster deploy config-server -c ob-config.yaml

# Step 3: Create Required Directories
# =============================================================================
echo "Creating required directories..."
if [ ! -d "/home/ds" ]; then
    mkdir -p "/home/ds"
    echo "Created /home/ds directory"
fi

# Step 4: Create Admin User Account
# =============================================================================
echo "Setting up admin user account..."
if ! id admin &>/dev/null; then
    echo "Creating admin user..."
    useradd -U -m -d /home/admin -s /bin/bash admin
    echo "admin user created successfully"

    # Set password for admin user
    echo "admin:123456" | chpasswd
    echo "Admin password set to: 123456"
else
    echo "Admin user already exists"
fi

# Step 5: Install OceanBase Database Package
# =============================================================================
echo "Installing OceanBase database package..."
rpm -ivh /app/oceanbase*.rpm

if [ $? -eq 0 ]; then
    echo "OceanBase package installed successfully"
else
    echo "OceanBase package installation failed"
    exit 1
fi

# Step 6: Set Proper Ownership for Admin User
# =============================================================================
echo "Setting ownership for admin user..."
chown -R admin:admin /home/admin
echo "Ownership set successfully"

# Step 7: Install OBProxy Package
# =============================================================================
echo "Installing OBProxy package..."
rpm -ivh --prefix=/home/admin /app/obproxy*.rpm

# Step 7.1: Locate and Link OBProxy Binary
# =============================================================================
echo "Configuring OBProxy binary..."
result=$(find / -name "obproxy-*" 2>/dev/null | grep /home/admin)

cat <<EOF | su - admin
# Check if OBProxy binary was found
if [ -z "$result" ]; then
    echo "OBProxy binary not found"
    exit 1
else
    echo "OBProxy binary found at: $result"
    ln -s "$result" /home/admin/obproxy
    echo "OBProxy symlink created successfully"
fi

# Load environment variables
source .bashrc

# Create log directories for OBProxy
mkdir -p /home/admin/logs/obproxy/log
echo "OBProxy log directories created"
EOF


# Step 8: Locate Java Installation
# =============================================================================
JAVA_DIR=$(ls -d /usr/lib/jvm/java-1.8.0-openjdk-* | head -n 1)

if [ -z "$JAVA_DIR" ]; then
    echo "Java installation not found in /usr/lib/jvm"
    exit 1
fi
echo "export JAVA_HOME=$JAVA_DIR
export JRE_HOME=\$JAVA_HOME/jre
export CLASSPATH=\$JAVA_HOME/lib:\$JRE_HOME/lib:\$CLASSPATH
export PATH=\$JAVA_HOME/bin:\$JRE_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$JRE_HOME/lib/amd64/server:/home/ds/oblogproxy/deps/lib "