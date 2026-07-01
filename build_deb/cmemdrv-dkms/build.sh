#!/bin/bash

SCRIPT_DIR=$(cd `dirname $` && pwd)
COMMIT=cbff149453ab1bb3597560cbfa3cec005bae0735
PKG=cmemdrv-dkms
VERSION=$(grep $PKG debian/changelog | sed -e 's/.*(//' -e 's/-.*).*//')
echo  $VERSION

wget -O cmemdrv_${VERSION}.orig.tar.gz \
    -c https://github.com/renesas-rcar/cmem/archive/${COMMIT}.tar.gz

rm -rf ${PKG}-${VERSION} ${PKG}-${VERSION}.orig.tar.gz
mkdir -p ${PKG}-${VERSION}/usr/src/${PKG}-${VERSION}
tar xf cmemdrv_${VERSION}.orig.tar.gz --strip-components=1 -C ${PKG}-${VERSION}
cp -r ${SCRIPT_DIR}/debian -t ${PKG}-${VERSION}
cp -r ${SCRIPT_DIR}/dkms/* -t ${PKG}-${VERSION}
sed -i ${PKG}-${VERSION}/debian/install -e "s/PKG/${PKG}/" -e "s/VERSION/$VERSION/"
tar czf ${PKG}_${VERSION}.orig.tar.gz ./${PKG}-${VERSION}

docker run --rm -i \
    -v ${SCRIPT_DIR}:/build:Z -u $(id -u):$(id -g) \
    -w /build/${PKG}-${VERSION} \
    debian-host-builder \
    dpkg-buildpackage -us -uc -a arm64

