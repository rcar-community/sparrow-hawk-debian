#!/bin/bash

SCRIPT_DIR=$(cd `dirname $0` && pwd)
RAW_VERSION=${1:-6.18.20-2026-04-01}
BRANCH=renesas-lts/v${RAW_VERSION}-sparrow-hawk
VERSION=$(echo $RAW_VERSION | cut -d'-' -f1)
PKG=sparrow-hawk-kernel-6.18
DEFCONFIG_NAME=sparrow_hawk_defconfig

cd ${SCRIPT_DIR}
git clone https://github.com/rcar-community/linux.git -b ${BRANCH} --depth 1
cd linux
git fetch origin ${BRANCH} --depth 1
git archive origin/${BRANCH} -o ../${PKG}_${VERSION}.orig.tar.gz

cd ${SCRIPT_DIR}
# Backup .version file
if [[ -e ${PKG}-${VERSION} ]]; then
    cp -f ${PKG}-${VERSION}/.version ${SCRIPT_DIR}/.version
fi

rm -rf ${PKG}-${VERSION}
mkdir ${PKG}-${VERSION}
tar xf ${PKG}_${VERSION}.orig.tar.gz --strip-components=0 -C ${PKG}-${VERSION}
cd ${PKG}-${VERSION}
while read line; do
    if [[ "$line" != "" ]]; then
        patch -p1 < ${SCRIPT_DIR}/patches/$line
    fi
done < ${SCRIPT_DIR}/patches/series
cat ${SCRIPT_DIR}/patches/*.cfg >> arch/arm64/configs/${DEFCONFIG_NAME}

# Restore .version file
if [[ -e ${SCRIPT_DIR}/${PKG}-${VERSION} ]]; then
    mv ${SCRIPT_DIR}/.version ./.version
fi

cat << EOS > ./build_kernel.sh
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export DEFCONFIG_NAME=${1:-sparrow_hawk_defconfig}

make -j$(nproc) ${DEFCONFIG_NAME}
make -j$(nproc) bindeb-pkg DPKG_FLAGS=-d
EOS

# Cleanup previous build artifacts
cd ${SCRIPT_DIR}
rm -rf *.deb *.buildinfo *.changes

docker run --rm -i \
    -v ${SCRIPT_DIR}:/build:Z -u $(id -u):$(id -g) \
    -w /build/${PKG}-${VERSION} \
    -v /etc/group:/etc/group:ro \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/shadow:/etc/shadow:ro \
    -v /etc/sudoers.d:/etc/sudoers.d:ro \
    debian-host-builder \
    bash ./build_kernel.sh


######################
# Build meta package #
######################

TARGETS=("linux-image" "linux-headers")

rm -rf ${SCRIPT_DIR}/build_meta
mkdir -p ${SCRIPT_DIR}/build_meta
cd ${SCRIPT_DIR}/build_meta

for target in ${TARGETS[@]}; do
    ORIG_PKG_NAME=$(ls ${SCRIPT_DIR}/${target}* | xargs basename | cut -d'_' -f1)
    PKG_VER=$(ls ${SCRIPT_DIR}/${target}* | xargs basename | cut -d'_' -f2)
    PKG_NAME=$(echo $ORIG_PKG_NAME | sed 's/\.[0-9]*-arm64/-arm64/')
    WORK_DIR=${PKG_NAME}_${PKG_VER}_arm64

    # Create meta package
    mkdir -p ${WORK_DIR}/DEBIAN
    cp ${SCRIPT_DIR}/debian_metapkg/control -t ${WORK_DIR}/DEBIAN/
    sed -i ${WORK_DIR}/DEBIAN/control \
        -e "s/__PACKAGE_NAME__/${PKG_NAME}/" \
        -e "s/__PACKAGE_VERSION__/${PKG_VER}/" \
        -e "s/__ORIGINAL_PACKAGE_NAME__/${ORIG_PKG_NAME}/"

    docker run --rm -i \
        -v ${SCRIPT_DIR}:/build:Z -u $(id -u):$(id -g) \
        -w /build/build_meta \
        -v /etc/group:/etc/group:ro \
        -v /etc/passwd:/etc/passwd:ro \
        -v /etc/shadow:/etc/shadow:ro \
        -v /etc/sudoers.d:/etc/sudoers.d:ro \
        debian-host-builder \
        dpkg-deb --root-owner-group --build ${WORK_DIR}

    # Cleanup
    rm -rf ${WORK_DIR}
done
cp ${SCRIPT_DIR}/build_meta/*.deb -t ${SCRIPT_DIR}

# Cleanup
rm -rf ${SCRIPT_DIR}/build_meta

