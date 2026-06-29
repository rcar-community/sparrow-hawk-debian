FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    build-essential \
    devscripts \
    debhelper \
    fakeroot \
    dh-make \
    dpkg-dev \
    lintian \
    git \
    ca-certificates \
    pkg-config \
    cmake \
    meson \
    ninja-build \
    bc kmod cpio flex libncurses5-dev libelf-dev libssl-dev dwarves bison \
    g++-aarch64-linux-gnu rsync dkms
# U-Boot dependency
RUN apt update && apt install -y \
    device-tree-compiler dfu-util efitools flex gdisk graphviz imagemagick \
    libgnutls28-dev libguestfs-tools libncurses-dev \
    libpython3-dev libsdl2-dev libssl-dev lz4 lzma lzma-alone openssl \
    pkg-config python3 python3-asteval python3-coverage python3-filelock \
    python3-pkg-resources python3-pycryptodome python3-pyelftools \
    python3-pytest python3-pytest-xdist python3-sphinxcontrib.apidoc \
    python3-sphinx-rtd-theme python3-subunit python3-testtools \
    python3-venv swig uuid-dev srecord

RUN apt update && apt install -y \
    mmdebstrap \
    parted \
    e2fsprogs \
    wget \
    dkms \
    && rm -rf /var/lib/apt/lists/*

RUN rm -rf /var/lib/apt/lists/*

WORKDIR /build
