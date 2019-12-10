#!/bin/bash
declare -a archlist=(
    "i686-ubuntu-linux-gnu"
    "x86_64-ubuntu-linux-gnu"
    "arm-ubuntu-linux-gnueabi"
    "aarch64-ubuntu-linux-gnu"
    "mipsel-ubuntu-linux-gnu"
    "mips64el-ubuntu-linux-gnu"
    "mips-ubuntu-linux-gnu"
    "mips64-ubuntu-linux-gnu"
)

for ARCH_PREFIX in "${archlist[@]}"; do
    echo "${ARCH_PREFIX}"
    CMD="sudo update-alternatives --remove-all ${ARCH_PREFIX}-gcc"
    eval "$CMD"
done

