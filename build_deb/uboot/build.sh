#!/bin/bash

SCRIPT_DIR=$(cd `dirname $0` && pwd)
PKG=sparrow-hawk-u-boot
VERSION=$(grep $PKG debian/changelog | sed -e 's/.*(//' -e 's/-.*).*//')
wget -O ${PKG}_${VERSION}.orig.tar.gz \
    -c https://github.com/u-boot/u-boot/archive/refs/tags/v${VERSION}.tar.gz

rm -rf ${PKG}-${VERSION}
mkdir ${PKG}-${VERSION}
tar xf ${PKG}_${VERSION}.orig.tar.gz --strip-components=1 -C ${PKG}-${VERSION}
cp -r ${SCRIPT_DIR}/debian -t ${PKG}-${VERSION}

docker run --rm -i \
    -v ${SCRIPT_DIR}:/build:Z -u $(id -u):$(id -g) \
    -w /build/${PKG}-${VERSION} \
    debian-host-builder \
    dpkg-buildpackage -us -uc -a arm64

