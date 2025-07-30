# Deploy OceanBase Log Proxy CE (CDC Mode)

## Introduction

The `oblogproxy-ce` Docker image, available on [dockerhub](https://hub.docker.com/r/oceanbase/oblogproxy-ce), [quay.io](https://quay.io/repository/oceanbase/oblogproxy-ce) and [ghcr.io](https://ghcr.io/oceanbase/oblogproxy-ce), is designed for users to quickly set up a Log Proxy CE instance for testing OceanBase CDC (Change Data Capture).

### Key Considerations:

- This image is intended for testing only; do not use it in production environments.
- This image supports the setup of a log proxy instance on cdc mode only.

## Prerequisites

Before deploying `oblogproxy-ce`, ensure that the following requirements are met:

- The OceanBase CE cluster is set up properly. Refer to [quick-start](https://github.com/oceanbase/oceanbase?tab=readme-ov-file#quick-start).
- Docker should be installed and running on the host machine. Refer to the [Docker installation guide](https://docs.docker.com/get-docker/).

## Starting an Log Proxy Instance

You'd better check the compatibility of oblogproxy first. See [releases](https://github.com/oceanbase/oblogproxy/releases).

To start a Log Proxy instance, use one of the following `docker run` commands:

```bash
# Deploy an instance without sys account info
docker run -p 2983:2983 --name oblogproxy-ce -d oceanbase/oblogproxy-ce

# Deploy an instance with sys account info
docker run -p 2983:2983 --name oblogproxy-ce -e OB_SYS_USERNAME=root -e OB_SYS_PASSWORD=123456 -d oceanbase/oblogproxy-ce
```

The bootstrap procedure shouldn't take too much time. Verify the bootstrap completion by running:

```
docker logs oblogproxy-ce | tail -1
```

Expected output:

```
boot success!
```

## Connecting to Log Proxy Instance

You can use the [oblogclient](https://github.com/oceanbase/oblogclient) to connect to the log proxy instance. See [oblogclient-sample](https://github.com/oceanbase/oblogclient/tree/master/oblogclient-sample) for more details.

## Supported Environment Variables

Below is a table of supported environment variables for the image:

| Variable name   | Default value | Description                      |
|-----------------|---------------|----------------------------------|
| OB_SYS_USERNAME |               | The username of sys tenant.      |
| OB_SYS_PASSWORD |               | The password of sys tenant user. |

Note:

- If the client sets the username and password of sys tenant, the variables above will be overwritten at session level.
- The password of sys user here must not be empty.
