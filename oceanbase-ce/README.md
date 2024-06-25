# How to deploy OceanBase with docker

## About
[oceanbase-ce](https://hub.docker.com/r/oceanbase/oceanbase-ce) is a test image for users to quickly setup an OceanBase environment. 

Before proceeding to the next step, please be aware of the following considerations:
- This image is for test purpose, so don't use it for production;
- This image only supports to setup single instance cluster;
- This image is not to run on Kubernetes, if you have the need to run containerized OceanBase on Kubernetes, please checkout [ob-operator](https://github.com/oceanbase/ob-operator) for detail.

## Prerequisite

Before you start to deploy `oceanbase-ce`, please make sure the following requirements are met:

- Make sure that your machine has enough resource that can provide least 2 physical cores and 8GB memory.
- Your machine has installed and started [Docker](https://docs.docker.com/get-docker/).

## Start an OceanBase instance

To start an OceanBase instance, run the following command:

```bash
# deploy mini mode instance
docker run -p 2881:2881 --name oceanbase-ce -d oceanbase/oceanbase-ce

# deploy an instance to use the full resource of container
docker run -p 2881:2881 --name oceanbase-ce -e MODE=normal -d oceanbase/oceanbase-ce

# deploy an instance using fastboot mode
docker run -p 2881:2881 --name oceanbase-ce -e MODE=slim -d oceanbase/oceanbase-ce

# deploy an instance and execute init sqls after bootstrap
docker run -p 2881:2881 --name oceanbase-ce -v {init_sql_folder_path}:/root/boot/init.d -d oceanbase/oceanbase-ce

```

The bootstrap procedure will take up to five minutes. You may run the following command to confirm the bootstrap procedure has successfully been done.

```bash
$ docker logs oceanbase-ce | tail -1
boot success!
```

## Connect to an OceanBase instance

The `oceanbase-ce` image contains `obclient` (OceanBase Database Client) and the default connection script `ob-mysql`. You may refer to the following commands to connect to OceanBase cluster.

```bash
docker exec -it oceanbase-ce ob-mysql sys # Connect with the root account of sys tenant
docker exec -it oceanbase-ce ob-mysql root # Connect with the root account of a general tenant
docker exec -it oceanbase-ce ob-mysql test # Connect with the test account of a general tenant
```

Or you can use the following command if your'd like to connect with your local `obclient` or `mysql` client directly.

Note: 
- The users created by script in the instance uses empty password by default.
- The general non-sys tenant is 'test' by default, so here we use 'root@test' as usernames.

```bash
mysql -h127.0.0.1 -P2881 -uroot  # Connect with the root account of sys tenant
mysql -h127.0.0.1 -P2881 -uroot@test  # Connect with the root account of a general tenant
```

## Supported environment variables

This table shows the supported environment variables of the image:

| Variable name           | Default value        | Description                                                                                                                                                                                                                                                                                                                                                                                                                                               |
|-------------------------|----------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| MODE                    | {mini, slim, normal} | mini indicates that the container will use the least amount of resource, normal indicates that the container will use as much as possible of the container resource, and slim indicates that the container will only start observer and using fastboot mode.                                                                                                                                                                                              |
| EXIT_WHILE_ERROR        | true                 | Whether quit the container when failed to start observer. if you set EXIT_WHILE_ERROR=false, the container will not exit and you can use log into the container for debugging.                                                                                                                                                                                                                                                                            |
| OB_CLUSTER_NAME         | obcluster            | The oceanbase cluster name                                                                                                                                                                                                                                                                                                                                                                                                                                |
| OB_TENANT_NAME          | test                 | The oceanbase mysql tenant name                                                                                                                                                                                                                                                                                                                                                                                                                           |
| OB_MEMORY_LIMIT         | 6G                   | The oceanbase cluster memory_limit configuration                                                                                                                                                                                                                                                                                                                                                                                                          |
| OB_DATAFILE_SIZE        | 5G                   | The oceanbase cluster datafile_size configuration                                                                                                                                                                                                                                                                                                                                                                                                         |
| OB_LOG_DISK_SIZE        | 5G                   | The oceanbase cluster log_disk_size configuration                                                                                                                                                                                                                                                                                                                                                                                                         |
| OB_SYS_PASSWORD         |                      | The oceanbase root user password of sys tenant                                                                                                                                                                                                                                                                                                                                                                                                            |
| OB_SYSTEM_MEMORY        | 1G                   | The oceanbase cluster system_memory configuration                                                                                                                                                                                                                                                                                                                                                                                                         |
| OB_TENANT_MINI_CPU      |                      | The oceanbase tenant mini_cpu configuration                                                                                                                                                                                                                                                                                                                                                                                                               |
| OB_TENANT_MEMORY_SIZE   |                      | The oceanbase tenant memory_size configuration                                                                                                                                                                                                                                                                                                                                                                                                            |
| OB_TENANT_LOG_DISK_SIZE |                      | The oceanbase tenant log_disk_size configuration                                                                                                                                                                                                                                                                                                                                                                                                          |

## Run the Sysbench script

`oceanbase-ce` image ships with a `sysbench` tool configured to run along with obd. You may run the following command to do a `sysbench` test.

```bash
docker exec -it oceanbase-ce obd test sysbench obcluster
```

## Data safety

`oceanbase-ce` deploys oceanbase under directory `/root/ob` and obd saves the configurations of oceanbase cluster under `/root/.obd/cluster` directory, you can mount directories on the host to `/root/ob` and `/root/.obd/cluster` to persist the data on host.
The example command is as follows

```bash
mkdir -p ob
mkdir -p obd/cluster
docker run -d -p 2881:2881 -v $PWD/ob:/root/ob -v $PWD/obd/cluster:/root/.obd/cluster --name oceanbase oceanbase/oceanbase-ce
```

## Fault Diagnosis
A series of diagnostic methods are provided to diagnose errors in Docker.

### Support for 'enable_rich_error_msg' parameter
Initially, the 'enable_rich_error_msg' parameter is enabled by default during the Docker startup process. If an error occurs during the startup process, rich error information can be obtained using the trace command.
