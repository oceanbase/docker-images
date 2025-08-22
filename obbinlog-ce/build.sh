#!/bin/bash
# @Params
# TARGETPLATFORM linux/amd64 or linux/arm64 (defaults to linux/amd64)
# This build script uses fixed compatible versions for all components
TARGETPLATFORM=${2:-linux/amd64}
docker build -t $1:latest --build-arg TARGETPLATFORM=$TARGETPLATFORM . 