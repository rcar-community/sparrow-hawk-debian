FROM --platform=linux/arm64 debian:bookworm

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
    bc kmod cpio flex libncurses5-dev libelf-dev libssl-dev dwarves bison

RUN apt update && apt install -y \
    meson build-essential ninja-build cmake libyaml-dev python3-yaml python3-ply python3-jinja2 \
    libevent-dev pkg-config python3-dev python3-pybind11 libdrm-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-bad1.0-dev \
    gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools gstreamer1.0-x \
    gstreamer1.0-alsa gstreamer1.0-gl gstreamer1.0-gtk3 gstreamer1.0-qt5 gstreamer1.0-pulseaudio

RUN rm -rf /var/lib/apt/lists/*

WORKDIR /build
