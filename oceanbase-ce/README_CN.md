[English](./README.md) | 中文版
# 使用Docker部署OceanBase

## 简介

`oceanbase-ce` Docker镜像旨在让用户快速搭建OceanBase测试环境, 镜像可在[dockerhub](https://hub.docker.com/r/oceanbase/oceanbase-ce)、[quay.io](https://quay.io/repository/oceanbase/oceanbase-ce)和[ghcr.io](https://ghcr.io/oceanbase/oceanbase-ce)获取。

### 重要注意事项：
- 此镜像在MacOS和intel芯片docker版本大于 4.9.0 的环境中有已知问题, 可以通过这个[链接](https://desktop.docker.com/mac/main/amd64/81317/Docker.dmg?_gl=17jelfd_gcl_auOTk5Nzk0MDUwLjE3MTE4ODMyNzM._gaNDQyMjE1MDE5LjE3MTE4ODMyNzQ._ga_XJWPQMJYHQ*MTcxOTIxOTEwMy4xMS4xLjE3MTkyMjEwMTAuNjAuMC4w)下载指定版本的docker。
- 此镜像仅用于测试目的；请勿在生产环境中使用。
- 该镜像仅支持单实例集群的设置。
- 此镜像不适用于Kubernetes。如需在Kubernetes上运行容器化的OceanBase，请参考[ob-operator](https://github.com/oceanbase/ob-operator)。

## 前提条件

在部署`oceanbase-ce`之前，请确保满足以下要求：
- 主机应至少具有2个物理核心和8GB内存。
- 主机上应安装并运行Docker。请参考[Docker安装指南](https://docs.docker.com/get-docker/)。

## 启动OceanBase实例

要启动OceanBase实例，请使用以下命令：

```bash
# 部署迷你模式实例
docker run -p 2881:2881 --name oceanbase-ce -d oceanbase/oceanbase-ce

# 部署最大规格实例以充分利用容器的全部资源
docker run -p 2881:2881 --name oceanbase-ce -e MODE=normal -d oceanbase/oceanbase-ce

# 使用快速启动模式部署实例
docker run -p 2881:2881 --name oceanbase-ce -e MODE=slim -d oceanbase/oceanbase-ce

# 启动后执行初始化SQL脚本，请勿在SQL脚本中更改root用户密码。
# 如果您想更改root用户密码，请使用OB_TENANT_PASSWORD环境变量。
docker run -p 2881:2881 --name oceanbase-ce -v {init_sql_folder_path}:/root/boot/init.d -d oceanbase/oceanbase-ce
```

启动过程可能需要长达五分钟。通过运行以下命令验证启动是否完成：

```
docker logs oceanbase-ce | tail -1
```

预期输出：
```
boot success!
```

## 连接到OceanBase实例
***注意***：
- 实例中创建的用户默认使用空密码。
- 默认的租户为'test'，请使用'root@test'作为用户名。

对于使用obclient或mysql客户端的本地连接：
```
mysql -h127.0.0.1 -P2881 -uroot       # 使用sys租户的root账户连接
mysql -h127.0.0.1 -P2881 -uroot@test  # 使用通用租户的root账户连接
```

## 支持的环境变量
以下是镜像支持的环境变量表：

| 变量名                  | 默认值               | 描述                                                                                                                                                                                                                                                                                                                                                                                                       |
|-------------------------|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| MODE                    | {mini, slim, normal} | mini表示容器将使用最少的资源<br>normal表示容器将尽可能使用容器的全部资源<br>slim表示容器将只启动observer并使用快速启动模式,租户名为 test,集群和租户资源相关的变量配置不生效。 |
| EXIT_WHILE_ERROR        | true                 | 当无法启动observer时是否退出容器。如果设置EXIT_WHILE_ERROR=false，容器将不会退出，您可以登录容器进行调试。                                                                                                                                                                                                                                                                                                 |
| OB_CLUSTER_NAME         | obcluster            | OceanBase集群名称                                                                                                                                                                                                                                                                                                                                                                                           |
| OB_TENANT_NAME          | test                 | OceanBase MySQL租户名称                                                                                                                                                                                                                                                                                                                                                                                     |
| OB_DATABASE             |                      | 在租户中创建的数据库，用于运行初始化脚本。                                                                                                                                                                                                                                                                                                                                                         |
| OB_MEMORY_LIMIT         | 6G                   | OceanBase集群memory_limit配置                                                                                                                                                                                                                                                                                                                                                                               |
| OB_DATAFILE_SIZE        | 5G                   | OceanBase集群datafile_size配置                                                                                                                                                                                                                                                                                                                                                                              |
| OB_LOG_DISK_SIZE        | 5G                   | OceanBase集群log_disk_size配置                                                                                                                                                                                                                                                                                                                                                                              |
| OB_SYS_PASSWORD         |                      | OceanBase sys租户root用户密码                                                                                                                                                                                                                                                                                                                                                                               |
| OB_TENANT_PASSWORD      |                      | OceanBase MySQL租户root用户密码                                                                                                                                                                                                                                                                                                                                                                             |
| OB_SYSTEM_MEMORY        | 1G                   | OceanBase集群system_memory配置                                                                                                                                                                                                                                                                                                                                                                              |
| OB_TENANT_MIN_CPU      |                      | OceanBase租户min_cpu配置                                                                                                                                                                                                                                                                                                                                                                                   |
| OB_TENANT_MEMORY_SIZE   |                      | OceanBase租户memory_size配置                                                                                                                                                                                                                                                                                                                                                                                |
| OB_TENANT_LOG_DISK_SIZE |                      | OceanBase租户log_disk_size配置                                                                                                                                                                                                                                                                                                                                                                              |
| OB_CONFIGSERVER_ADDRESS |                      | ob-configserver 地址, 示例: http://1.1.1.1:8080                                                                                                                                                                                                                                                                                                                                                                                                       |

## 运行Sysbench脚本
oceanbase-ce镜像包含sysbench工具用于基准测试。使用以下命令运行sysbench测试：
```
docker exec -it oceanbase-ce obd test sysbench obcluster
```

## 数据持久化
默认情况下，oceanbase-ce在/root/ob下部署OceanBase，并在/root/.obd/cluster下保存其配置。使用以下命令在主机上持久化数据：

```
mkdir -p ob
mkdir -p obd/cluster
docker run -d -p 2881:2881 -v $PWD/ob:/root/ob -v $PWD/obd/cluster:/root/.obd/cluster --name oceanbase oceanbase/oceanbase-ce
```

## 故障诊断
Docker启动时默认启用enable_rich_error_msg参数。如果发生错误，您可以使用trace命令获取详细的错误信息。
