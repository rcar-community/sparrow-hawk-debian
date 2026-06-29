#!/bin/bash

SCRIPT_DIR=$(cd `dirname $` && pwd)
COMMIT=72a861aab57e0529b0f24ea2febdaa7afce52fda
PKG=qos-dkms
VERSION=$(grep $PKG debian/changelog | sed -e 's/.*(//' -e 's/-.*).*//')
MODULE_NAME=qos
echo  $VERSION

wget -O qosdrv_${VERSION}.orig.tar.gz \
    -c https://github.com/renesas-rcar/qos_drv/archive/${COMMIT}.tar.gz

rm -rf ${PKG}-${VERSION} ${PKG}-${VERSION}.orig.tar.gz
mkdir -p ${PKG}-${VERSION}/usr/src/${PKG}-${VERSION}
tar xf qosdrv_${VERSION}.orig.tar.gz --strip-components=1 -C ${PKG}-${VERSION}
cp -r ${SCRIPT_DIR}/debian -t ${PKG}-${VERSION}
cp -r ${SCRIPT_DIR}/dkms/* -t ${PKG}-${VERSION}
sed -i ${PKG}-${VERSION}/debian/install -e "s/PKG/${PKG}/" -e "s/VERSION/$VERSION/"
sed -i ${PKG}-${VERSION}/debian/post* -e "s/__MODULE_NAME__/${PKG}/"  -e "s/__MODULE_VERSION__/${VERSION}/"
sed -i ${PKG}-${VERSION}/debian/pre* -e "s/__MODULE_NAME__/${PKG}/"  -e "s/__MODULE_VERSION__/${VERSION}/"
tar czf ${PKG}_${VERSION}.orig.tar.gz ./${PKG}-${VERSION}

docker run --rm -i \
    -v ${SCRIPT_DIR}:/build:Z -u $(id -u):$(id -g) \
    -w /build/${PKG}-${VERSION} \
    debian-host-builder \
    dpkg-buildpackage -us -uc -a arm64

