#!/bin/bash
if [ -z "$TOOL_PATH" ]; then
    echo "env \$TOOL_PATH should be defined first."
    echo "source scripts/env.sh"
    exit
fi

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

declare -a slavelist=(
    "addr2line"
    "ar"
    "as"
    "c++"
    "cc"
    "c++filt"
    "cpp"
    "ct-ng.config"
    "elfedit"
    "g++"
    "gcc-8.2.0"
    "gcc-ar"
    "gcc-nm"
    "gcc-ranlib"
    "gcov"
    "gcov-dump"
    "gcov-tool"
    "gprof"
    "ld"
    "ld.bfd"
    "ldd"
    "nm"
    "objcopy"
    "objdump"
    "populate"
    "ranlib"
    "readelf"
    "size"
    "strings"
    "strip"
)

COMPVER="8.2.0"

for ARCH_PREFIX in "${archlist[@]}"; do
    TOOLCHAIN_PATH="${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}/bin/${ARCH_PREFIX}"
    SYSROOT="${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}/${ARCH_PREFIX}/sysroot"

    echo "${ARCH_PREFIX}"
    CMD="sudo update-alternatives --force --install /usr/bin/${ARCH_PREFIX}-gcc \
    ${ARCH_PREFIX}-gcc ${TOOLCHAIN_PATH}-gcc 100"

    for slave in "${slavelist[@]}"; do
        CMD="${CMD} --slave /usr/bin/${ARCH_PREFIX}-${slave} \
    ${ARCH_PREFIX}-${slave} \
    ${TOOLCHAIN_PATH}-${slave}"
    done
    eval "$CMD"

    # give write permission to set symbolic link
    chmod o+w -R "${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}"

    # some compilation environment do not search sysroot.
    CWD=$(pwd)
    cd "${SYSROOT}/../lib"
    ln -sf ../sysroot/lib/* ./
    ln -sf ../sysroot/usr/lib/* ./
    cd $CWD
done

