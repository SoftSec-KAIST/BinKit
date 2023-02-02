#!/bin/bash
sudo apt-get update -q

declare -a PACKAGES=(
    parallel
    build-essential
    binutils
    cmake
    autogen
    autoconf
    automake
    tar wget git
    texinfo
    help2man
    libtool
    libtool-bin
    bison
    flex
    unzip
    gperf
    libncurses-dev
)

for PACKAGE in "${PACKAGES[@]}"; do
    sudo apt-get install -y -q "$PACKAGE"
done

