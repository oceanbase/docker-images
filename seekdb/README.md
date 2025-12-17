English | [中文版](./README_CN.md)
# Deploy seekdb with Docker

## Introduction

The `seekdb` Docker image, available on [dockerhub](https://hub.docker.com/r/oceanbase/seekdb), [quay.io](https://quay.io/repository/oceanbase/seekdb) and [ghcr.io](https://ghcr.io/oceanbase/seekdb), is designed for users to quickly set up a seekdb environment for testing purposes.

### Key Considerations:
- There are known issues running this image on MacOS and intel chip with docker version greater than 4.9.0, you can download the desired version of docker from this [link](https://desktop.docker.com/mac/main/amd64/81317/Docker.dmg?_gl=17jelfd_gcl_auOTk5Nzk0MDUwLjE3MTE4ODMyNzM._gaNDQyMjE1MDE5LjE3MTE4ODMyNzQ._ga_XJWPQMJYHQ*MTcxOTIxOTEwMy4xMS4xLjE3MTkyMjEwMTAuNjAuMC4w).
- This image is intended for testing only; do not use it in production environments.

## Prerequisites

Before deploying `seekdb`, ensure that the following requirements are met:
- The host machine should have at least 1 physical cores and 2GB of memory.
- Docker should be installed and running on the host machine. Refer to the [Docker installation guide](https://docs.docker.com/get-docker/).

## Starting a seekdb Instance

To start a seekdb instance, use the following commands:

```bash
docker run -d -p 2881:2881 -p 2886:2886 oceanbase/seekdb

# Execute init SQL scripts after bootstrap, you need to mount the directory containing the init scripts then specify the directory in container via environment variable INIT_SCRIPTS_PATH.
# Please do not change root user's password in SQL scripts. If you'd like to change root user's password, use environment variable ROOT_PASSWORD.
docker run -d -p 2881:2881 -p 2886:2886 -v {init_sql_folder_path}:/root/boot/init.d -e INIT_SCRIPTS_PATH=/root/boot/init.d oceanbase/seekdb
```

## Supported Environment Variables
Below is a table of supported environment variables for the image:

| Variable name           | Description                                                                                                                                                                                                                                                                                                                                                                                                                                               |
|-------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ROOT_PASSWORD           | The password of user root                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| CPU_COUNT               | The value of cpu_count, e.g. 4.                                                                                                                                                                                                                                                                                                                                                                                                                           |
| MEMORY_LIMIT            | The value of memory_limit, e.g. 2G.                                                                                                                                                                                                                                                                                                                                                                                                                       |
| LOG_DISK_SIZE           | The value of log_disk_size, e.g. 2G.                                                                                                                                                                                                                                                                                                                                                                                                                      |
| DATAFILE_SIZE           | The value of datafile_size, e.g. 2G.                                                                                                                                                                                                                                                                                                                                                                                                                      |
| DATAFILE_NEXT           | The value of datafile_next, e.g. 2G.                                                                                                                                                                                                                                                                                                                                                                                                                      |
| DATAFILE_MAXSIZE        | The value of datafile_maxsize, e.g. 50G.                                                                                                                                                                                                                                                                                                                                                                                                                  |
| INIT_SCRIPTS_PATH       | The path in the container containing the init scripts.                                                                                                                                                                                                                                                                                                                                                                                                    |
| SEEKDB_DATABASE         | The name of the database to be created at startup.                                                                                                                                                                                                                                                                                                                                                                                                        |

If you'd like to modify other seekdb parameters, you can do mount a configuration file into `/etc/oceanbase/seekdb.cnf` in the container, the default configuration file is as follows.

```
datafile_size=2G
datafile_next=2G
datafile_maxsize=50G
cpu_count=4
memory_limit=2G
log_disk_size=2G
# config the parameter in the following format
# key=value
```

The start command should be like this.
```
# **Note:** If you decide to use a configuration file, please don't specify the resource related environment variables.
docker run -d -p 2881:2881 -p 2886:2886 -v {config_file}:/etc/oceanbase/seekdb.cnf oceanbase/seekdb
```

## Data Persistence
Seekdb deploys in directory /var/lib/oceanbase, if you'd like to persist the data on the host server, please mount an empty directory on the host server to this path.
***NOTE***: If you run seekdb container on windows, please use docker volume instead of directory on the host to ensure it works properly.

```
# On Linux or MacOS
mkdir -p seekdb
docker run -d -p 2881:2881 -p 2886:2886 -v $PWD/seekdb:/var/lib/oceanbase --name seekdb oceanbase/seekdb

# On Windows
docker volume create seekdb
docker run -d -p 2881:2881 -p 2886:2886 -v seekdb:/var/lib/oceanbase --name seekdb oceanbase/seekdb
```

## Connecting to seekdb Instance

```
mysql -h 127.0.0.1 -P 2881 -u root -p    # Connect with the root account
```

## Access dashboard
The container provides a user-friendly web interface, you can access it in the browser `http://${server_ip}:2886`, the login password is the same as user root's password. If ROOT_PASSWORD is not set, leave the password field blank.

