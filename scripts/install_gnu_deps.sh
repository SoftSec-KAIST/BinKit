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
    libtoolize
    libtoolize-dev
    libcposix
    libcposix-dev
    libpcap
    libpcap-dev
    libdnet
    libdnet-dev
    libdumbnet
    libdumbnet-dev
    daq
    libdaq-dev
    libluajit
    libluajit-dev
    libluajit-5.1-dev
    libnghttp2-dev
    apr
    libapr1-dev libaprutil1-dev
    libcurl*-dev
    libcurl\*-dev
    libcapstone-dev
    nasm yasm
    libqt-dev
    libqt5-dev
    libqt4-dev
    curl
    libcurl-dev
    libcurl4-openssl-dev
    ssh
    libssl-dev
    git-core git-svn subversion
    checkinstall
    dh-make
    debhelper
    ant ant-optional
    liblzo2-dev libzip-dev
    sharutils
    libfuse-dev
    reprepro
    asciidoc
    xmlto
    libterm
    libterminal-dev
    libterminal1-dev
    libterm-dev
    ltermlib
    ncurses
    ncurses-dev
    libncurses
    libncurses-dev
    libxcurses
    libxcurses-dev
    libnxcurses
    libnxcurses-dev
    libncursesw5
    libncursesw5-dev
    libncurses5
    libncurses5-dev
    lib32ncursesw5
    librsvg-2.0
    librsvg2-dev
    libgnomeprintui2
    libgnome2-dev
    libpopt-dev
    libtinfo-dev
    gdkglext-1.0
    pkgconfig
    python3-pkgconfig
    cvs
    gawk
    postfix
)

for PACKAGE in "${PACKAGES[@]}"; do
    sudo apt-get install -y -q "$PACKAGE"
done

## to compile dataset
#sudo apt-get install gcc-multilib
#sudo apt-get install gcc-multilib-arm-linux-gnueabi
#sudo apt-get install gcc-multilib-mipsel-linux-gnu

