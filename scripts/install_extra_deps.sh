#!/bin/bash

if [ -z "$EXTRA_DEP_PATH" ]; then
  EXTRA_DEP_PATH="$TOOL_PATH/extra_dep"
  export EXTRA_DEP_PATH
fi

mkdir -p $EXTRA_DEP_PATH
mkdir -p $EXTRA_DEP_PATH/sources

# build libidn for x86_64
mkdir -p $EXTRA_DEP_PATH/install_x86_64
cd $EXTRA_DEP_PATH/sources
wget https://ftp.gnu.org/gnu/libidn/libidn-1.0.tar.gz
tar -xvf libidn-1.0.tar.gz
mkdir -p libidn-1.0/build && cd libidn-1.0/build
../configure --prefix="$EXTRA_DEP_PATH/install_x86_64"
make -j 8 && make install

# build libuuid for x86_64
mkdir -p $EXTRA_DEP_PATH/install_x86_64
cd $EXTRA_DEP_PATH/sources
wget http://sourceforge.net/projects/libuuid/files/libuuid-1.0.0.tar.gz
tar -xvf libuuid-1.0.0.tar.gz
mkdir -p libuuid-1.0.0/build && cd libuuid-1.0.0/build
../configure --prefix="$EXTRA_DEP_PATH/install_x86_64"
make -j 8 && make install

##! glibc here
# build glibc for x86_64
# build glibc for x86_32
# build glibc for arm_32
