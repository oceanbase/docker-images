 # OceanBase Binlog CE Docker 镜像

[English](./README.md) | 中文版

本目录包含用于构建 OceanBase Binlog CE Docker 镜像的 Dockerfile 和脚本。

## 概述

`obbinlog-ce` Docker 镜像提供了完整的 OceanBase 数据库环境，包含 binlog 服务，包括：

- OceanBase Observer（数据库服务器）
- OBProxy（连接代理）
- Binlog Service（数据复制服务）
- Configuration Server（配置服务器）

**注意**：此镜像使用固定的兼容版本以确保所有组件之间的兼容性。

**重要提示**：该镜像仅用于测试使用，不可用于生产环境。比如 GitHub CI 场景下的集成测试请使用它。

## 构建镜像

### 本地构建

```bash
# 构建 x86_64 版本（使用固定兼容版本）
docker build -t obbinlog-ce:latest --build-arg TARGETPLATFORM=linux/amd64 .

# 构建 ARM64 版本（使用固定兼容版本）
docker build -t obbinlog-ce:latest --build-arg TARGETPLATFORM=linux/arm64 .
```

### 使用构建脚本

```bash
# 构建 x86_64 版本（使用固定兼容版本）
./build.sh obbinlog-ce

# 构建 ARM64 版本（使用固定兼容版本）
./build.sh obbinlog-ce linux/arm64
```

## 运行容器

```bash
# 基本运行
docker run -d -p 2881:2881 -p 2883:2883 --name obbinlog-ce obbinlog-ce:latest

# 自定义配置运行
docker run -d \
  -p 2881:2881 \
  -p 2883:2883 \
  -e CLUSTER_NAME=mycluster \
  -e TENANT_NAME=mytentant \
  -e PASSWORD=mypassword \
  --name obbinlog-ce \
  obbinlog-ce:latest
```

## 环境变量

| 变量名 | 默认值 | 描述 |
|--------|--------|------|
| CLUSTER_NAME | ob | OceanBase 集群名称 |
| TENANT_NAME | test | 租户名称 |
| PASSWORD | 123456 | 系统密码 |
| DATAFILE_SIZE | 2G | 数据文件大小 |
| LOG_DISK_SIZE | 4G | 日志磁盘大小 |

## 端口

- `2881`：OceanBase Observer JDBC 端口
- `2882`：OceanBase Observer RPC 端口
- `2883`：OBProxy 端口

## 连接数据库

```bash
# 连接到 sys 租户
mysql -h127.0.0.1 -P2881 -uroot

# 连接到 test 租户
mysql -h127.0.0.1 -P2881 -uroot@test
```

## 发布新版本

要发布新版本：

1. 创建新标签：
   ```bash
   git tag obbinlog-ce-v1.0.0
   git push origin obbinlog-ce-v1.0.0
   ```

2. GitHub Actions 工作流将自动：
   - 使用固定兼容版本为 x86_64 和 ARM64 构建镜像
   - 推送到 Docker Hub、Quay.io 和 GitHub Container Registry
   - 使用标签名作为镜像标签

## 架构支持

- `linux/amd64`：x86_64 架构
- `linux/arm64`：ARM64 架构

## 故障排除

### 构建问题

1. 检查版本是否存在于 OceanBase 仓库中
2. 验证与 mirrors.aliyun.com 的网络连接
3. 确保构建有足够的磁盘空间

### 运行时问题

1. 检查容器日志：`docker logs obbinlog-ce`
2. 验证端口可用性
3. 检查系统资源（内存、CPU）

## 许可证

Apache License 2.0