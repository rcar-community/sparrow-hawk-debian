#!/bin/bash -eu

SCRIPT_DIR=$(cd `dirname $0` && pwd)
cd ${SCRIPT_DIR}

for pkg in $(ls -d */); do
    echo "Build $pkg"
    cd ${SCRIPT_DIR}/${pkg}
    ./build.sh
done

