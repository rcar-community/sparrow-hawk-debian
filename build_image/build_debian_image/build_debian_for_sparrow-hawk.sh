#!/bin/bash -eu

#################################
# Configuable parameter         #
#################################
HOSTNAME=sparrow-hawk
USERNAME=rcar # Default password is same as USERNAME
EXTRA_IMAGE_SIZE=1000 # MiB
ADDITIONAL_PACKAGE=""
VARIANT=debootstrap # minbase # default=debootstrap

#################################
# Fixed parameter               #
#################################
DEVICE=sparrow-hawk # Currently, it doesn't support to change device.
REPO_OWNER=${REPO_OWNER:-$(git remote -v | grep origin | head -1 | sed -e 's/.*github\.com[:/]//' -e 's/\/.*//')}
REPO_BRANCH=apt-repo
BRANCH=${BRANCH:-$(git branch | grep '*' | cut -d' ' -f2)}
EXTRA_APT_COMMON_CONF="arch=arm64 trusted=yes signed-by=/etc/apt/trusted.gpg.d/sparrow-hawk-repo.asc"
EXTRA_APT_REPO="\
# Repo list(main=stable, dev=development, next=release candidate)
#deb [${EXTRA_APT_COMMON_CONF}] https://${REPO_OWNER}.github.io/sparrow-hawk-debian/main _CODENAME_ main
#deb [${EXTRA_APT_COMMON_CONF}] https://${REPO_OWNER}.github.io/sparrow-hawk-debian/dev  _CODENAME_ main
#deb [${EXTRA_APT_COMMON_CONF}] https://${REPO_OWNER}.github.io/sparrow-hawk-debian/next _CODENAME_ main
deb [${EXTRA_APT_COMMON_CONF}] https://${REPO_OWNER}.github.io/sparrow-hawk-debian/${BRANCH} _CODENAME_ main
"
GPG_KEY_URL="https://${REPO_OWNER}.github.io/sparrow-hawk-debian/sparrow-hawk-repo.asc"
ARCH=arm64
SCRIPT_DIR=$(cd `dirname $0` && pwd)
CHROOT_DIR=${SCRIPT_DIR}/rootfs
NET_DEV=end0
USE_LOCAL_DEB="no"
IMAGE_NAME_POSTFIX=""
DEBIAN_VER=13

DHCP_CONF="
[Match]
Name=${NET_DEV}
[Network]
DHCP=ipv4
"
BASE_PKG=" \
    systemd dbus net-tools iproute2 \
    sudo passwd login adduser tzdata locales \
    vim net-tools ssh tzdata rsyslog udev wget \
    kmod nano systemd-resolved systemd-timesyncd \
"
UTIL_PKG=" \
    pciutils usbutils alsa-utils i2c-tools can-utils psmisc \
    unzip curl git htop parted \
    python3 python3-pip python3-venv python3-dev python3-libgpiod \
"
PKG_LIST=" \
    ${BASE_PKG} \
    ${UTIL_PKG} \
    ${ADDITIONAL_PACKAGE} \
"

#################################
# Function                      #
#################################
Usage () {
    echo "Usage:"
    echo "    $0 [OPTIONS]"
    echo "OPTIONS:"
    echo "    -h | --help:          Show this help"
    echo "    -l | --use-local-deb: Use local deb package instead of kernel-apt-repo(For development)"
    echo "       | --desktop <pkg>: Add task-<pkg>-desktop package into image"
    echo "       | --version <num>: Set target debian version(ex.13)"
    exit
}

Get_codename_from_version () {
    VERSION=$1
    curl -s https://debian.pages.debian.net/distro-info-data/debian.csv \
        | grep ^${VERSION}, | cut -d',' -f3
}

#################################
# Main process                  #
#################################
# Check version and codename
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            DEBIAN_VER=$2
            shift ;;
        --desktop)
            DESKTOP_ENV=$2
            PKG_LIST+=" task-${DESKTOP_ENV}-desktop "
            IMAGE_NAME_POSTFIX="-${DESKTOP_ENV}"
            shift ;;
        -l|--use-local-deb)
            USE_LOCAL_DEB="yes" ;;
        -h|--help)
            Usage; exit 0 ;;
        *) ;; # Ignore unknown option
    esac
    shift
done
CODENAME=$( Get_codename_from_version ${DEBIAN_VER} )
if [[ $CODENAME == "" ]]; then
    Usage; exit -1
fi
echo $CODENAME
EXTRA_APT_REPO=$(echo "${EXTRA_APT_REPO}" | sed "s/_CODENAME_/$CODENAME/g")

IMAGE_NAME=${DEVICE}-debian-${DEBIAN_VER}-based-bsp${IMAGE_NAME_POSTFIX}.img

# root privilege is needed for this script
if [ "`whoami`" != "root" ]; then
    echo "Error: Root privilege is needed. Try again with sudo or root user."
    exit -1
fi

echo "Download gpg key for debian repository to Host PC"
 wget -c -q --directory-prefix /etc/apt/trusted.gpg.d/ https://ftp-master.debian.org/keys/archive-key-${DEBIAN_VER}.asc
 wget -c -q --directory-prefix /etc/apt/trusted.gpg.d/ https://ftp-master.debian.org/keys/archive-key-${DEBIAN_VER}-security.asc

echo "Run mmdebstrap to make initial rootfs"
rm -rf ${CHROOT_DIR}
INSTALL_KERNEL_PACKAGE="apt-get install -y sparrow-hawk-bsp"
mmdebstrap --variant=$VARIANT --arch=$ARCH \
    --include="ca-certificates ${PKG_LIST}" $CODENAME ${CHROOT_DIR} \
    \
    --customize-hook="echo \"${DHCP_CONF}\" > ${CHROOT_DIR}/etc/systemd/network/01-${NET_DEV}.network" \
    --customize-hook="echo ${HOSTNAME} > ${CHROOT_DIR}/etc/hostname" \
    --customize-hook="echo 127.0.0.1 localhost > ${CHROOT_DIR}/etc/hosts" \
    --customize-hook="echo 127.0.1.1 ${HOSTNAME} >> ${CHROOT_DIR}/etc/hosts" \
    --customize-hook="chroot ${CHROOT_DIR} addgroup gpio" \
    --customize-hook="chroot ${CHROOT_DIR} useradd -m -s /bin/bash -G sudo,audio,video,i2c,gpio,dialout ${USERNAME}" \
    --customize-hook="chroot ${CHROOT_DIR} sh -c 'echo ${USERNAME}:${USERNAME} | chpasswd'" \
    --customize-hook="echo \"${USERNAME}   ALL=(ALL) NOPASSWD:ALL\" >> ${CHROOT_DIR}/etc/sudoers" \
    --customize-hook="curl -fsSL ${GPG_KEY_URL} -o ${CHROOT_DIR}/etc/apt/trusted.gpg.d/sparrow-hawk-repo.asc" \
    --customize-hook="echo \"$EXTRA_APT_REPO\" | tee ${CHROOT_DIR}/etc/apt/sources.list.d/sparrow-hawk-repo.list > /dev/null" \
    --customize-hook="chroot ${CHROOT_DIR} rm /etc/resolv.conf" \
    --customize-hook="echo nameserver 1.1.1.1 >  ${CHROOT_DIR}/etc/resolv.conf" \
    --customize-hook="echo nameserver 8.8.8.8 >> ${CHROOT_DIR}/etc/resolv.conf" \
    --customize-hook="chroot ${CHROOT_DIR} apt-get update" \
    --customize-hook="chroot ${CHROOT_DIR} ${INSTALL_KERNEL_PACKAGE}" \
    --customize-hook="chroot ${CHROOT_DIR} depmod -a \$(ls ${CHROOT_DIR}/lib/modules)" \
    \
    --customize-hook="chroot ${CHROOT_DIR} apt-get clean" \
    --customize-hook="chroot ${CHROOT_DIR} rm /etc/resolv.conf" \
    --customize-hook="chroot ${CHROOT_DIR} systemctl enable systemd-networkd" \
    --customize-hook="chroot ${CHROOT_DIR} systemctl enable systemd-resolved" \
    --customize-hook="chroot ${CHROOT_DIR} ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf" \
    || false

# Other setup
## Remount rootfs
echo '/dev/root  /  auto  defaults  1  1' >> ${CHROOT_DIR}/etc/fstab
## GPIO udev rule
echo 'SUBSYSTEM=="gpio", MODE="0660", GROUP="gpio"' > ${CHROOT_DIR}/etc/udev/rules.d/50-gpio.rules
## I2C application symlinl
for path in $(cd ${CHROOT_DIR} && ls usr/sbin/i2c* ); do ln -sf /${path} ${CHROOT_DIR}/usr/bin/; done

echo "Make flashable image from rootfs"
USED_SIZE=$(du --max-depth=1 ${CHROOT_DIR} | tail -1 | awk '{print int($1/1000)}')
IMAGE_SIZE=$(( $USED_SIZE + $EXTRA_IMAGE_SIZE ))
mkdir -p ./tmp

dd if=/dev/zero of=${IMAGE_NAME} bs=1M count=${IMAGE_SIZE}
parted ./${IMAGE_NAME} mklabel msdos mkpart primary ext4 1MiB 100%
SEEK=$(fdisk -l ${IMAGE_NAME} | grep img1 | awk '{print $2}')
SECTORS=$(fdisk -l ${IMAGE_NAME} | grep img1 | awk '{print $4}')
PART_SIZE_MB=$(( ${SECTORS} * 512 / 1024 / 1024))
dd if=/dev/zero of=rootfs.ext4 bs=512 count=${SECTORS}
mkfs.ext4 -L reformsdroot -d ${CHROOT_DIR} rootfs.ext4 ${PART_SIZE_MB}M
dd if=rootfs.ext4 of=${IMAGE_NAME} bs=512 seek=${SEEK} conv=notrunc
gzip -f ./${IMAGE_NAME}

echo "Cleanup"
rm -rf ${CHROOT_DIR} ./tmp rootfs.ext4

echo "Finished"

