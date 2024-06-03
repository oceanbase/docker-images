#!/bin/bash
# @Params
# TARGETPLATFORM linux/amd64 or linux/arm64
# VERSION: x.y.z-r e.g. 4.2.2-100000042024011120 which combines VERSION and RELEASE
docker build -t $1:$2 --build-arg VERSION=$2 --build-arg TARGETPLATFORM=$3 .
