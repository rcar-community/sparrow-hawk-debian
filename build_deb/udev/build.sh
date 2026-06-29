#!/bin/bash

SCRIPT_DIR=$(cd `dirname $0` && pwd)
PKG=sparrow-hawk-udev
VERSION=$(grep $PKG debian/changelog | sed -e 's/.*(//' -e 's/-.*).*//')

rm -rf ${PKG}_${VERSION}.orig.tar.gz
tar czf ${PKG}_${VERSION}.orig.tar.gz src

rm -rf ${PKG}-${VERSION}
mkdir ${PKG}-${VERSION}
tar xf ${PKG}_${VERSION}.orig.tar.gz --strip-components=1 -C ${PKG}-${VERSION}
cd ${PKG}-${VERSION}

cp -r ../debian ./

docker run --rm -i \
    -v ${SCRIPT_DIR}:/build:Z -u $(id -u):$(id -g) \
    -w /build/${PKG}-${VERSION} \
    debian-host-builder \
    dpkg-buildpackage -us -uc -a arm64

