# =============================================================================
# OceanBase Database with Binlog Service Dockerfile
# =============================================================================
# This Dockerfile creates a containerized OceanBase database with binlog service
# Includes OceanBase Observer, OBProxy, and Binlog components
# =============================================================================

FROM openanolis/anolisos

# =============================================================================
# Step 1: Set Environment Variables and Working Directory
# =============================================================================
ARG TARGETPLATFORM
WORKDIR /

# =============================================================================
# Step 2: Configure Package Manager and Install Dependencies
# =============================================================================
# Configure yum repositories and install system dependencies
RUN set -eux; \
    yum install -y yum-utils && \
    yum-config-manager --add-repo https://mirrors.aliyun.com/oceanbase/OceanBase.repo && \
    # Install required packages
    yum install -y \
        jq \
        obclient \
        java-1.8.0-openjdk* \
        diffutils \
        compat-openssl10 \
        ob-deploy \
        tree \
        vim \
        less \
        initscripts \
        libaio \
        gcc \
        sudo && \
    # Clean up yum cache
    yum clean all && \
    # Create app directory
    mkdir -p /app

# =============================================================================
# Step 3: Download OceanBase Packages
# =============================================================================
# Download OceanBase components with fixed compatible versions
RUN set -eux; \
    echo "Target platform: ${TARGETPLATFORM}" && \
    if [[ ${TARGETPLATFORM} == 'linux/amd64' ]] ; then \
        echo "Downloading packages for x86_64..." && \
        # Download OceanBase Observer for x86_64 (fixed version)
        curl -f -L -o /app/oceanbase-ce.rpm \
            https://mirrors.aliyun.com/oceanbase/community/stable/el/8/x86_64/oceanbase-ce-4.3.5.1-101010042025042417.el8.x86_64.rpm && \
        # Download OceanBase Libraries for x86_64 (fixed version)
        curl -f -L -o /app/oceanbase-ce-libs.rpm \
            https://mirrors.aliyun.com/oceanbase/community/stable/el/8/x86_64/oceanbase-ce-libs-4.3.5.1-101010042025042417.el8.x86_64.rpm && \
        # Download OBProxy for x86_64 (fixed version)
        curl -f -L -o /app/obproxy-ce.rpm \
            https://mirrors.aliyun.com/oceanbase/community/stable/el/8/x86_64/obproxy-ce-4.3.4.0-1.el8.x86_64.rpm && \
        # Download Binlog Service for x86_64 (fixed version)
        curl -f -L -o /app/obbinlog-ce.rpm \
            https://mirrors.aliyun.com/oceanbase/community/stable/el/8/x86_64/obbinlog-ce-4.2.5-100000042025052216.el8.x86_64.rpm && \
        echo "x86_64 packages downloaded successfully" ; \
    else \
        echo "Downloading packages for ARM64..." && \
        # Download OceanBase Observer for aarch64 (fixed version)
        curl -f -L -o /app/oceanbase-ce.rpm \
            https://mirrors.aliyun.com/oceanbase/community/stable/el/8/aarch64/oceanbase-ce-4.3.5.1-101010042025042417.el8.aarch64.rpm && \
        # Download OceanBase Libraries for aarch64 (fixed version)
        curl -f -L -o /app/oceanbase-ce-libs.rpm \
            https://mirrors.aliyun.com/oceanbase/community/stable/el/8/aarch64/oceanbase-ce-libs-4.3.5.1-101010042025042417.el8.aarch64.rpm && \
        # Download OBProxy for aarch64 (fixed version)
        curl -f -L -o /app/obproxy-ce.rpm \
            https://mirrors.aliyun.com/oceanbase/community/stable/el/8/aarch64/obproxy-ce-4.3.4.0-1.el8.aarch64.rpm && \
        # Download Binlog Service for aarch64 (fixed version)
        curl -f -L -o /app/obbinlog-ce.rpm \
            https://mirrors.aliyun.com/oceanbase/community/stable/el/8/aarch64/obbinlog-ce-4.2.5-100000042025052216.el8.aarch64.rpm && \
        echo "ARM64 packages downloaded successfully" ; \
    fi && \
    # Verify downloaded files
    echo "Verifying downloaded packages..." && \
    ls -la /app/*.rpm && \
    echo "All packages downloaded and verified successfully"

# =============================================================================
# Step 4: Copy Configuration Scripts
# =============================================================================
# Copy and set permissions for configuration scripts
ADD config.sh /app/
ADD start_services.sh /app/

# =============================================================================
# Step 5: Configure System Limits
# =============================================================================
# Increase process limits for OceanBase
RUN echo "* soft nproc 65535" >> /etc/security/limits.conf
RUN echo "* hard nproc 65535" >> /etc/security/limits.conf

# =============================================================================
# Step 6: Execute Configuration and Cleanup
# =============================================================================
# Run configuration script and clean up installation files
RUN set -eux; \
    # Set execute permissions
    chmod +x /app/*.sh && \
    # Execute configuration script
    /app/config.sh && \
    # Clean up yum cache and installation files
    rm -rf /var/cache/yum/* && \
    rm -rf /app/oceanbase* && \
    rm -rf /app/obproxy* && \
    # Verify cleanup
    echo "Installation and configuration completed successfully"

# =============================================================================
# Step 7: Set Entry Point
# =============================================================================
# Configure container entry point
ENTRYPOINT ["/app/start_services.sh"]