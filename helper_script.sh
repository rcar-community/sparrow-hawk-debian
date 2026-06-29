#!/bin/bash

if [[ $# < 1 ]]; then
    echo "Usage: $0 <deb paths>"
    exit -1
fi

UpdateDeb () {
    PKG_NAME=$(basename $1 | cut -f1 -d_)

    targets=("bookworm" "trixie")
    if [[ "$(echo $1 | grep +deb12)" != "" ]]; then
        targets=("bookworm")
    elif [[ "$(echo $1 | grep +deb13)" != "" ]]; then
        targets=("trixie")
    fi

    for codename in ${targets[@]} ; do
        reprepro remove $codename $PKG_NAME
    done
    for codename in ${targets[@]}; do
        reprepro includedeb $codename $1
    done
}

for arg in $@; do
    UpdateDeb $arg
done

