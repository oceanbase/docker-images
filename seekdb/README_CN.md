中文版 | [English](./README.md)
# 使用 Docker 部署 seekdb

## 简介

`seekdb` Docker 镜像，可在 [dockerhub](https://hub.docker.com/r/oceanbase/seekdb)、[quay.io](https://quay.io/repository/oceanbase/seekdb) 和 [ghcr.io](https://ghcr.io/oceanbase/seekdb) 获取，旨在帮助用户快速搭建 seekdb 环境进行测试。

### 主要注意事项：
- 在 MacOS 和 Intel 芯片上运行此镜像时，如果 Docker 版本高于 4.9.0，存在已知问题。您可以从此 [链接](https://desktop.docker.com/mac/main/amd64/81317/Docker.dmg?_gl=17jelfd_gcl_auOTk5Nzk0MDUwLjE3MTE4ODMyNzM._gaNDQyMjE1MDE5LjE3MTE4ODMyNzQ._ga_XJWPQMJYHQ*MTcxOTIxOTEwMy4xMS4xLjE3MTkyMjEwMTAuNjAuMC4w) 下载所需版本的 Docker。
- 此镜像仅用于测试；请勿在生产环境中使用。

## 先决条件

在部署 `seekdb` 之前，请确保满足以下要求：
- 主机应至少有 1 个物理核心和 2GB 内存。
- 主机上应安装并运行 Docker。请参阅 [Docker 安装指南](https://docs.docker.com/get-docker/)。

## 启动 seekdb 实例

要启动 seekdb 实例，请使用以下命令：

```bash
docker run -d -p 2881:2881 -p 2886:2886 oceanbase/seekdb

# 在引导后执行初始化 SQL 脚本，您需要挂载包含初始化脚本的目录，然后通过环境变量 INIT_SCRIPTS_PATH 指定容器中的挂载目录。
# 请勿在 SQL 脚本中更改 root 用户的密码。如果您想更改 root 用户的密码，请使用环境变量 ROOT_PASSWORD。
docker run -d -p 2881:2881 -p 2886:2886 -v {init_sql_folder_path}:/root/boot/init.d -e INIT_SCRIPTS_PATH=/root/boot/init.d oceanbase/seekdb
```

## 支持的环境变量
下表列出了镜像支持的环境变量：

| 变量名           | 描述                                                                                                                                                                                                                                                                                                                                                                                                                                               |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ROOT_PASSWORD           | root 用户的密码                                                                                                                                                                                                                                                                                                                                                                                                                           |
| CPU_COUNT               | cpu_count 的值，例如 4。                                                                                                                                                                                                                                                                                                                                                                                                                  |
| MEMORY_LIMIT            | memory_limit 的值，例如 2G。                                                                                                                                                                                                                                                                                                                                                                                                              |
| LOG_DISK_SIZE           | log_disk_size 的值，例如 2G。                                                                                                                                                                                                                                                                                                                                                                                                             |
| DATAFILE_SIZE           | datafile_size 的值，例如 2G。                                                                                                                                                                                                                                                                                                                                                                                                             |
| DATAFILE_NEXT           | datafile_next 的值，例如 2G。                                                                                                                                                                                                                                                                                                                                                                                                             |
| DATAFILE_MAXSIZE        | datafile_maxsize 的值，例如 50G。                                                                                                                                                                                                                                                                                                                                                                                                         |
| INIT_SCRIPTS_PATH       | 容器中包含初始化脚本的路径。                                                                                                                                                                                                                                                                                                                                                                                                              |
| SEEKDB_DATABASE         | 启动时要创建的数据库名称。                                                                                                                                                                                                                                                                                                                                                                                                                          |

如果您想修改其他 seekdb 参数，可以将配置文件挂载到容器中的 `/etc/oceanbase/seekdb.cnf`，默认配置文件如下。

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

启动命令应如下所示。
```
# **注意：** 如果您决定使用配置文件，请不要指定与资源相关的环境变量。
docker run -d -p 2881:2881 -p 2886:2886 -v {config_file}:/etc/oceanbase/seekdb.cnf oceanbase/seekdb
```

## 数据持久化
Seekdb 部署在 `/var/lib/oceanbase` 目录中，如果您想将数据持久化到主机服务器，请将主机服务器上的空目录挂载到此路径。
***注意***: 如果您在 Windows 系统上运行 seekdb 容器，请使用 docker volume 以确保容器能正常工作。

```
# On Linux or MacOS
mkdir -p seekdb
docker run -d -p 2881:2881 -p 2886:2886 -v $PWD/seekdb:/var/lib/oceanbase --name seekdb oceanbase/seekdb

# On Windows
docker volume create seekdb
docker run -d -p 2881:2881 -p 2886:2886 -v seekdb:/var/lib/oceanbase --name seekdb oceanbase/seekdb
```

## 连接到 seekdb 实例

```
mysql -h 127.0.0.1 -P 2881 -u root -p    # 使用 root 帐户连接
```

## 访问 obshell dashboard
容器提供了一个用户友好的 Web 界面，您可以通过浏览器访问 `http://${server_ip}:2886`，登录密码与 root 用户的密码相同。如果未设置 ROOT_PASSWORD，请将密码字段留空。
