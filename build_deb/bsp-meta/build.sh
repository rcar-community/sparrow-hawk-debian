#!/bin/bash

SCRIPT_DIR=$(cd `dirname $0` && pwd)
PKG=sparrow-hawk-bsp
VERSION=$(grep $PKG debian/changelog | sed -e 's/.*(//' -e 's/-.*).*//')

rm -rf ${PKG}-${VERSION}
mkdir ${PKG}-${VERSION}
cd ${PKG}-${VERSION}

cp -r ../debian ./
dpkg-buildpackage -us -uc

docker run --rm -i \
    -v ${SCRIPT_DIR}:/build:Z -u $(id -u):$(id -g) \
    -w /build/${PKG}-${VERSION} \
    debian-host-builder \
    dpkg-buildpackage -us -uc -a arm64

