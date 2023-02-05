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

# build glibc for x86_64
mkdir -p $EXTRA_DEP_PATH/install_x86_64
cd $EXTRA_DEP_PATH/sources
wget https://ftp.gnu.org/gnu/glibc/glibc-2.32.tar.gz
tar -xvf glibc-2.32.tar.gz
rm -rf glibc-2.32/build
mkdir -p glibc-2.32/build && cd glibc-2.32/build
../configure --prefix="$EXTRA_DEP_PATH/install_x86_64" \
  CC="gcc" CXX="g++" CFLAGS="-O2" CXXFLAGS="-O2"
make -j 8 && make install

# build glibc for x86_32
mkdir -p $EXTRA_DEP_PATH/install_x86_32
cd $EXTRA_DEP_PATH/sources
wget https://ftp.gnu.org/gnu/glibc/glibc-2.32.tar.gz
tar -xvf glibc-2.32.tar.gz
rm -rf glibc-2.32/build
mkdir -p glibc-2.32/build && cd glibc-2.32/build
../configure --prefix="$EXTRA_DEP_PATH/install_x86_32" \
  --host=i686-linux-gnu \
  --build=i686-linux-gnu \
  CC="gcc -m32" CXX="g++ -m32" \
  CFLAGS="-O2 -march=i686" \
  CXXFLAGS="-O2 -march=i686"
make -j 8 && make install
