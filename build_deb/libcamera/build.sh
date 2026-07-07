#!/bin/bash

SCRIPT_DIR=$(cd `dirname $0` && pwd)
COMMIT=f4c3dee21770b9b8817c80265b9f81eda1833731
PKG=sparrow-hawk-libcamera
VERSION=$(grep $PKG debian/changelog | sed -e 's/.*(//' -e 's/-.*).*//')
DEBIAN_VER=""
# Check version and codename
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            DEBIAN_VER=$2
            shift ;;
        *) ;; # Ignore unknown option
    esac
    shift
done
# Check version
if [[ "${DEBIAN_VER}" == "" ]];then
    echo "Warning: Target debian version is not specified, so all versions are built."
    $0 --version 12
    $0 --version 13
    exit 0
fi

cd ${SCRIPT_DIR}
git clone https://gitlab.freedesktop.org/camera/libcamera.git
cd libcamera
git fetch
git archive ${COMMIT} -o ../${PKG}_${VERSION}.orig.tar.gz

cd ${SCRIPT_DIR}
rm -rf ${PKG}-${VERSION}
mkdir ${PKG}-${VERSION}
tar xf ${PKG}_${VERSION}.orig.tar.gz --strip-components=0 -C ${PKG}-${VERSION}

cp -r ${SCRIPT_DIR}/debian -t ${PKG}-${VERSION}
sed -i ${PKG}-${VERSION}/debian/changelog \
    -e "s/\(${VERSION}-[0-9]*\)/\1+deb${DEBIAN_VER}/"

docker run --rm -i --platform linux/arm64 \
    -v ${SCRIPT_DIR}:/build:Z -u $(id -u):$(id -g) \
    -w /build/${PKG}-${VERSION} \
    debian-${DEBIAN_VER}-arm64-builder \
    dpkg-buildpackage -us -uc -a arm64

