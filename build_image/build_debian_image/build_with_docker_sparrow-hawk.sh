#!/bin/bash -eu

SCRIPT_DIR=$(cd `dirname $0` && pwd)
cd ${SCRIPT_DIR}

REPO_OWNER=$(git -C ${SCRIPT_DIR} remote -v | grep origin | head -1 | sed -e 's/.*github\.com[:/]//' -e 's/\/.*//')
BRANCH=$(git -C ${SCRIPT_DIR} rev-parse --abbrev-ref HEAD)

docker run --rm --cap-add SYS_ADMIN --security-opt seccomp=unconfined --security-opt apparmor=unconfined \
    -w /work -v $(pwd):/work \
    -e REPO_OWNER=${REPO_OWNER} \
    -e BRANCH=${BRANCH} \
    debian-host-builder ./build_debian_for_sparrow-hawk.sh $@

