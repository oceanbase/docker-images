# OceanBase Binlog CE Docker Image

English | [中文版](./README_CN.md)

This directory contains the Dockerfile and scripts to build the OceanBase Binlog CE Docker image.

## Overview

The `obbinlog-ce` Docker image provides a complete OceanBase database environment with binlog service, including:

- OceanBase Observer (database server)
- OBProxy (connection proxy)
- Binlog Service (data replication service)
- Configuration Server

**Note**: This image uses fixed compatible versions for all components to ensure compatibility.

**Important**: This image is for testing purposes only and should not be used in production environments. It is suitable for integration testing scenarios such as GitHub CI.

## Building the Image

### Local Build

```bash
# Build for x86_64 (uses fixed compatible versions)
docker build -t obbinlog-ce:latest --build-arg TARGETPLATFORM=linux/amd64 .

# Build for ARM64 (uses fixed compatible versions)
docker build -t obbinlog-ce:latest --build-arg TARGETPLATFORM=linux/arm64 .
```

### Using Build Script

```bash
# Build for x86_64 (uses fixed compatible versions)
./build.sh obbinlog-ce

# Build for ARM64 (uses fixed compatible versions)
./build.sh obbinlog-ce linux/arm64
```

## Running the Container

```bash
# Basic run
docker run -d -p 2881:2881 -p 2883:2883 --name obbinlog-ce obbinlog-ce:latest

# With custom configuration
docker run -d \
  -p 2881:2881 \
  -p 2883:2883 \
  -e CLUSTER_NAME=mycluster \
  -e TENANT_NAME=mytentant \
  -e PASSWORD=mypassword \
  --name obbinlog-ce \
  obbinlog-ce:latest
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| CLUSTER_NAME | ob | OceanBase cluster name |
| TENANT_NAME | test | Tenant name |
| PASSWORD | 123456 | System password |
| DATAFILE_SIZE | 2G | Data file size |
| LOG_DISK_SIZE | 4G | Log disk size |

## Ports

- `2881`: OceanBase Observer JDBC port
- `2882`: OceanBase Observer RPC port  
- `2883`: OBProxy port

## Connecting to the Database

```bash
# Connect to sys tenant
mysql -h127.0.0.1 -P2881 -uroot

# Connect to test tenant
mysql -h127.0.0.1 -P2881 -uroot@test
```

## Publishing New Versions

To publish a new version:

1. Create a new tag:
   ```bash
   git tag obbinlog-ce-v1.0.0
   git push origin obbinlog-ce-v1.0.0
   ```

2. The GitHub Actions workflow will automatically:
   - Build the image for both x86_64 and ARM64 using fixed compatible versions
   - Push to Docker Hub, Quay.io, and GitHub Container Registry
   - Tag with the tag name

## Architecture Support

- `linux/amd64`: x86_64 architecture
- `linux/arm64`: ARM64 architecture

## Troubleshooting

### Build Issues

1. Check if the version exists in the OceanBase repository
2. Verify network connectivity to mirrors.aliyun.com
3. Ensure sufficient disk space for the build

### Runtime Issues

1. Check container logs: `docker logs obbinlog-ce`
2. Verify port availability
3. Check system resources (memory, CPU)

## License

Apache License 2.0 