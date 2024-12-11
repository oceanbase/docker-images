English | [中文版](./README_CN.md)
# Deploy OceanBase with Docker

## Introduction

The `oceanbase-ce` Docker image, available on [dockerhub](https://hub.docker.com/r/oceanbase/oceanbase-ce), [quay.io](https://quay.io/repository/oceanbase/oceanbase-ce) and [ghcr.io](https://ghcr.io/oceanbase/oceanbase-ce), is designed for users to quickly set up an OceanBase environment for testing purposes.

### Key Considerations:
- There are known issues running this image on MacOS and intel chip with docker version greater than 4.9.0, you can download the desired version of docker from this [link](https://desktop.docker.com/mac/main/amd64/81317/Docker.dmg?_gl=17jelfd_gcl_auOTk5Nzk0MDUwLjE3MTE4ODMyNzM._gaNDQyMjE1MDE5LjE3MTE4ODMyNzQ._ga_XJWPQMJYHQ*MTcxOTIxOTEwMy4xMS4xLjE3MTkyMjEwMTAuNjAuMC4w).
- This image is intended for testing only; do not use it in production environments.
- The image supports the setup of a single-instance cluster only.
- This image is not designed for Kubernetes. For running containerized OceanBase on Kubernetes, refer to the [ob-operator](https://github.com/oceanbase/ob-operator) repository.

## Prerequisites

Before deploying `oceanbase-ce`, ensure that the following requirements are met:
- The host machine should have at least 2 physical cores and 8GB of memory.
- Docker should be installed and running on the host machine. Refer to the [Docker installation guide](https://docs.docker.com/get-docker/).

## Starting an OceanBase Instance

To start an OceanBase instance, use one of the following `docker run` commands:

```bash
# Deploy a mini mode instance
docker run -p 2881:2881 --name oceanbase-ce -d oceanbase/oceanbase-ce

# Deploy an instance to utilize the full resource of the container
docker run -p 2881:2881 --name oceanbase-ce -e MODE=normal -d oceanbase/oceanbase-ce

# Deploy an instance using fastboot mode
docker run -p 2881:2881 --name oceanbase-ce -e MODE=slim -d oceanbase/oceanbase-ce

# Execute init SQL scripts after bootstrap, do not change root user's password in SQL scripts. 
# If you'd like to change root user's password, use variable OB_TENANT_PASSWORD.
docker run -p 2881:2881 --name oceanbase-ce -v {init_sql_folder_path}:/root/boot/init.d -d oceanbase/oceanbase-ce
```

The bootstrap procedure may take up to five minutes. Verify the bootstrap completion by running:

```
docker logs oceanbase-ce | tail -1
```

Expected output:
```
boot success!
```

## Connecting to OceanBase Instance
***Note***:
- Users created in the instance via script use empty passwords by default.
- The default general non-sys tenant is 'test', so 'root@test' is used as the username.

For local connections using obclient or mysql client:
```
mysql -h127.0.0.1 -P2881 -uroot       # Connect with the root account of sys tenant
mysql -h127.0.0.1 -P2881 -uroot@test  # Connect with the root account of a general tenant
```

## Supported Environment Variables
Below is a table of supported environment variables for the image:

| Variable name           | Default value        | Description                                                                                                                                                                                                                                                                                                                                                                                                                                               |
|-------------------------|----------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| MODE                    | {mini, slim, normal} | mini indicates that the container will use the least amount of resource<br>normal indicates that the container will use as much as possible of the container resource<br>slim indicates that the container will only start observer and using fastboot mode, the tenant is named as test, cluster and tenant resource configurations will not take effect.                                                                                                        |
| EXIT_WHILE_ERROR        | true                 | Whether quit the container when failed to start observer. if you set EXIT_WHILE_ERROR=false, the container will not exit and you can use log into the container for debugging.                                                                                                                                                                                                                                                                            |
| OB_CLUSTER_NAME         | obcluster            | The oceanbase cluster name                                                                                                                                                                                                                                                                                                                                                                                                                                |
| OB_TENANT_NAME          | test                 | The oceanbase mysql tenant name                                                                                                                                                                                                                                                                                                                                                                                                                           |
| OB_MEMORY_LIMIT         | 6G                   | The oceanbase cluster memory_limit configuration                                                                                                                                                                                                                                                                                                                                                                                                          |
| OB_DATAFILE_SIZE        | 5G                   | The oceanbase cluster datafile_size configuration                                                                                                                                                                                                                                                                                                                                                                                                         |
| OB_LOG_DISK_SIZE        | 5G                   | The oceanbase cluster log_disk_size configuration                                                                                                                                                                                                                                                                                                                                                                                                         |
| OB_SYS_PASSWORD         |                      | The oceanbase root user password of sys tenant                                                                                                                                                                                                                                                                                                                                                                                                            |
| OB_TENANT_PASSWORD      |                      | The oceanbase root user password of mysql tenant                                                                                                                                                                                                                                                                                                                                                                                                          |
| OB_SYSTEM_MEMORY        | 1G                   | The oceanbase cluster system_memory configuration                                                                                                                                                                                                                                                                                                                                                                                                         |
| OB_TENANT_MIN_CPU      |                      | The oceanbase tenant min_cpu configuration                                                                                                                                                                                                                                                                                                                                                                                                               |
| OB_TENANT_MEMORY_SIZE   |                      | The oceanbase tenant memory_size configuration                                                                                                                                                                                                                                                                                                                                                                                                            |
| OB_TENANT_LOG_DISK_SIZE |                      | The oceanbase tenant log_disk_size configuration                                                                                                                                                                                                                                                                                                                                                                                                          |
| OB_CONFIGSERVER_ADDRESS |                      | Address of ob-configserver e.g. http://1.1.1.1:8080                                                                                                                                                                                                                                                                                                                                                                                                       |
## Running Sysbench Script
The oceanbase-ce image includes the sysbench tool for benchmarking. Use the following command to run a sysbench test:
```
docker exec -it oceanbase-ce obd test sysbench obcluster
```

## Data Persistence
By default, oceanbase-ce deploys OceanBase under /root/ob and saves its configurations under /root/.obd/cluster. Use the following command to persist data on the host:

```
mkdir -p ob
mkdir -p obd/cluster
docker run -d -p 2881:2881 -v $PWD/ob:/root/ob -v $PWD/obd/cluster:/root/.obd/cluster --name oceanbase oceanbase/oceanbase-ce
```

## Fault Diagnosis
The enable_rich_error_msg parameter is enabled by default during Docker startup. If an error occurs, you can obtain detailed error information using the trace command.
