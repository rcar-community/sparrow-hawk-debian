#!/bin/bash

SCRIPT_DIR=$(cd `dirname $0` && pwd)
cd $SCRIPT_DIR

docker build --platform linux/arm64 -t debian-12-arm64-builder ./_dev/arm64/debian12
docker build --platform linux/arm64 -t debian-13-arm64-builder ./_dev/arm64/debian13
docker build -t debian-host-builder ./_dev/host

