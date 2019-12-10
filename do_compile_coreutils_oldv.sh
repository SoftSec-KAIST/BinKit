#!/bin/bash

FTPURL="https://ftp.gnu.org/gnu/coreutils"
WORK_DIR="$BASEDIR/sources/coreutils"
OUTDIR="$BASEDIR/output/coreutils"
LOGDIR="$BASEDIR/logs/coreutils"
PACKAGE_NAME="coreutils"

function join_by { local IFS="$1"; shift; echo "$*"; }

ARGS=$@
ARGS_STR=$(join_by _ $ARGS)

ECHO=false
OPTIONS=""
SUFFIX=""

# -fno-var-tracking due to gcc-4.9.4 O1
OPTIONS="${OPTIONS} -g -fno-var-tracking"
SUFFIX="${SUFFIX}_debug"

echo "COMPILING: ${PACKAGE_NAME}-${SUFFIX}"
echo "OUTDIR: ${OUTDIR}"
echo "OPTIONS: ${OPTIONS}"

declare -a arch_list=(
    "x86_32"
    "x86_64"
    "arm_32"
    "arm_64"
    "mips_32"
    "mips_64"
    "mipseb_32"
    "mipseb_64"
)

declare -a opti_list=(
    "O0"
    "O1"
    "O2"
    "O3"
)

declare -a compiler_list=(
    "gcc-4.9.4"
    "gcc-5.5.0"
    "gcc-6.4.0"
    "gcc-7.3.0"
    "gcc-8.2.0"
    "clang-4.0"
    "clang-5.0"
    "clang-6.0"
    "clang-7.0"
)

LOGDIR="${LOGDIR}${SUFFIX}"
CONFIGDIR="${LOGDIR}/configure/"
MAKEDIR="${LOGDIR}/make/"
mkdir -p $LOGDIR $CONFIGDIR $MAKEDIR

# for version 6.5 and 6.7,
# should configure on the top directory of the coreutil project
# therefore, commented out build folder
#declare -a versions=("6.7")
#declare -a versions=("6.5")
declare -a versions=(
    "6.5"
    "6.7"
)

PATCH=$(<patches/coreutils_65_67_aarch64.patch)

function doit()
{
    local VER=$1
    local COMPILER=$2
    local ARCH=$3
    local OPT=$4
    local CMD=$5
    local OPTIONS="${OPTIONS}"
    local EXTRA="${EXTRA}"


    if [[ $ARCH =~ "eb_" ]]; then
        OPTIONS="${OPTIONS} -EB"
    fi

    ARCH_X86="i686-ubuntu-linux-gnu"
    ARCH_X8664="x86_64-ubuntu-linux-gnu"
    ARCH_ARM="arm-ubuntu-linux-gnueabi"
    ARCH_ARM64="aarch64-ubuntu-linux-gnu"
    ARCH_MIPS="mipsel-ubuntu-linux-gnu"
    ARCH_MIPS64="mips64el-ubuntu-linux-gnu"
    ARCH_MIPSEB="mips-ubuntu-linux-gnu"
    ARCH_MIPSEB64="mips64-ubuntu-linux-gnu"

    if [[ $COMPILER =~ "gcc" ]]; then
        COMPVER=${COMPILER#"gcc-"}

    elif [[ $COMPILER =~ "clang" ]]; then
        # using LLVM-obfuscator
        if [[ $COMPILER =~ "obfus" ]]; then
            OBFUS=${COMPILER#clang-obfus-}
            if [[ $OBFUS =~ "all" ]]; then
                EXTRA="${EXTRA} -mllvm -fla -mllvm -sub -mllvm -bcf"
            else
                EXTRA="${EXTRA} -mllvm -${OBFUS}"
            fi
        fi

        # fix compiler version for clang
        COMPVER="8.2.0"
        export PATH="${TOOL_PATH}/clang/${COMPILER}/bin:${PATH}"

        # clang lto is only supported by lld
        if [[ $SUFFIX =~ "lto" ]]; then
            OPTIONS="${OPTIONS} -fuse-ld=lld"
        fi

    else
        echo "DO NOT SUPPORT THIS COMPILER: $COMPILER"
        exit
    fi

    if [[ $ARCH == "arm_32" ]]; then
        ARCH_PREFIX=$ARCH_ARM
    elif [[ $ARCH == "arm_64" ]]; then
        ARCH_PREFIX=$ARCH_ARM64
    elif [[ $ARCH == "mips_32" ]]; then
        ARCH_PREFIX=$ARCH_MIPS
        OPTIONS="${OPTIONS} -mips32r2"
    elif [[ $ARCH == "mips_64" ]]; then
        ARCH_PREFIX=$ARCH_MIPS64
        OPTIONS="${OPTIONS} -mips64r2"
    elif [[ $ARCH == "mipseb_32" ]]; then
        ARCH_PREFIX=$ARCH_MIPSEB
        OPTIONS="${OPTIONS} -mips32r2"
    elif [[ $ARCH == "mipseb_64" ]]; then
        ARCH_PREFIX=$ARCH_MIPSEB64
        OPTIONS="${OPTIONS} -mips64r2"
    elif [[ $ARCH == "x86_32" ]]; then
        ARCH_PREFIX=$ARCH_X86
        OPTIONS="${OPTIONS} -m32"
    elif [[ $ARCH == "x86_64" ]]; then
        ARCH_PREFIX=$ARCH_X8664
    fi

    export PATH="${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}/bin:${PATH}"
    SYSROOT="${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}/${ARCH_PREFIX}/sysroot"
    SYSTEM="${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}/${ARCH_PREFIX}/sysroot/usr/include"

    OPTIONS="${OPTIONS} -${OPT}"
    if [[ $COMPILER =~ "gcc" ]]; then
        CMD=""
        CMD="--host=\"${ARCH_PREFIX}\""
        CMD="${CMD} CFLAGS=\" ${OPTIONS}"
        CMD="${CMD} -isysroot ${SYSROOT} -isystem ${SYSTEM} -I${SYSTEM}\""
        CMD="${CMD} LDFLAGS=\"${OPTIONS}\""
        CMD="${CMD} AR=\"${ARCH_PREFIX}-gcc-ar\""
        CMD="${CMD} RANLIB=\"${ARCH_PREFIX}-gcc-ranlib\""
        CMD="${CMD} NM=\"${ARCH_PREFIX}-gcc-nm\""

    elif [[ $COMPILER =~ "clang" ]]; then
        CMD="CC=\"clang\""
        CMD="${CMD} --host=\"${ARCH_PREFIX}\""
        CMD="${CMD} CFLAGS=\" ${OPTIONS} ${EXTRA} --target=${ARCH_PREFIX}"
        CMD="${CMD} --gcc-toolchain=${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}"
        CMD="${CMD} -isysroot ${SYSROOT} -isystem ${SYSTEM} -I${SYSTEM}\""
        CMD="${CMD} LDFLAGS=\"${OPTIONS}\""
        CMD="${CMD} AR=\"llvm-ar\""
        CMD="${CMD} RANLIB=\"llvm-ranlib\""
        CMD="${CMD} NM=\"llvm-nm\""
    fi
    CMD="./configure --build=x86_64-linux-gnu ${CMD}"
    CMD2="make -j ${NUM_JOBS} -l ${MAX_JOBS}"

    if ! $ECHO; then
        COMPILETYPE="${COMPILER}_${ARCH}_${OPT}"
        CONFIGDIR="${LOGDIR}/configure/"
        MAKEDIR="${LOGDIR}/make/"
        CMD="${CMD} >${CONFIGDIR}/${PACKAGE_NAME}-${VER}_${COMPILETYPE}${SUFFIX}_configure_error.log 2>&1"
        CMD2="${CMD2} >${MAKEDIR}/${PACKAGE_NAME}-${VER}_${COMPILETYPE}${SUFFIX}_make_error.log 2>&1"
    fi

    eval "${CMD}"

    if [ -f Makefile ]; then
        # one should wrap variables with "" ...
        sed -i 's/ CC=\$\${CC:-\$(CC)}/ CC="\$\${CC:-\$(CC)}"/' Makefile
        sed -i 's/ CC=\$(CC)/ CC="$(CC)"/' Makefile
    fi

    eval "${CMD2}"

    cnt=0
    for b in "${bin_list[@]}"
    do
        if [ -f $b ]; then
            cp "${b}" "${NEW_OUTDIR}/${PACKAGE_NAME}-${VER}_${COMPILER}_${ARCH}_${OPT}_${b##*/}"
            cnt=$(( $cnt + 1 ))
        else
            #      echo "COMPILE ${b} FAILED"
            :
        fi
    done

    if [ $cnt -eq ${#bin_list[@]} ]; then
        :
        #    echo "$cnt COMPILE SUCCESS!!"
    else
        echo "COMPILE $VER $COMPILER $ARCH $OPT FAILED"
        if [ -f config.log ]; then
            cp config.log "${CONFIGDIR}/${PACKAGE_NAME}-${VER}_${COMPILETYPE}${SUFFIX}_config.log"
        fi
    fi
}


function helper()
{
    local ver=$1
    local comp=$2
    local arch=$3
    local opti=$4

    if $ECHO; then
        echo "[+] running $ver $comp $arch $opti ----"
    fi

    declare -a bin_list=(
        "./src/base64"
        "./src/basename"
        "./src/cat"
        "./src/chgrp"
        "./src/chmod"
        "./src/chown"
        "./src/chroot"
        "./src/cksum"
        "./src/comm"
        "./src/cp"
        "./src/csplit"
        "./src/cut"
        "./src/date"
        #    "./src/dcgen"
        "./src/dd"
        #    "./src/df"
        "./src/dir"
        "./src/dircolors"
        "./src/dirname"
        "./src/du"
        "./src/echo"
        "./src/env"
        "./src/expand"
        "./src/expr"
        "./src/factor"
        "./src/false"
        "./src/fmt"
        "./src/fold"
        "./src/ginstall"
        #    "./src/groups"
        "./src/head"
        "./src/hostid"
        "./src/hostname"
        "./src/id"
        "./src/join"
        "./src/kill"
        "./src/link"
        "./src/ln"
        "./src/logname"
        "./src/ls"
        "./src/md5sum"
        "./src/mkdir"
        "./src/mkfifo"
        "./src/mknod"
        "./src/mv"
        "./src/nice"
        "./src/nl"
        "./src/nohup"
        "./src/od"
        "./src/paste"
        "./src/pathchk"
        "./src/pinky"
        "./src/pr"
        "./src/printenv"
        "./src/printf"
        "./src/ptx"
        "./src/pwd"
        "./src/readlink"
        "./src/rm"
        "./src/rmdir"
        "./src/seq"
        "./src/setuidgid"
        "./src/sha1sum"
        "./src/sha224sum"
        "./src/sha256sum"
        "./src/sha384sum"
        "./src/sha512sum"
        "./src/shred"
        "./src/shuf"
        "./src/sleep"
        "./src/sort"
        "./src/split"
        "./src/stat"
        "./src/stty"
        "./src/su"
        "./src/sum"
        "./src/sync"
        "./src/tac"
        "./src/tail"
        "./src/tee"
        "./src/test"
        "./src/touch"
        "./src/tr"
        "./src/true"
        "./src/tsort"
        "./src/tty"
        "./src/uname"
        "./src/unexpand"
        "./src/uniq"
        "./src/unlink"
        "./src/uptime"
        "./src/users"
        "./src/vdir"
        "./src/wc"
        "./src/who"
        "./src/whoami"
        "./src/yes"
    )


    COMPILETYPE="${comp}_${arch}_${opti}"
    NEW_WORK_DIR="${WORK_DIR}-${ver}_${COMPILETYPE}${SUFFIX}"
    NEW_OUTDIR="${OUTDIR}/${ver}"
    mkdir -p $NEW_OUTDIR

    GO=true
    for b in "${bin_list[@]}"
    do
        if [ ! -f "${NEW_OUTDIR}/${PACKAGE_NAME}-${ver}_${comp}_${arch}_${opti}_${b##*/}" ]; then
            GO=false
        fi
    done

    if $GO; then
        #echo "${ver}_${comp}_${arch}_${opti} already done."
        cd ..
        rm -rf $NEW_WORK_DIR
        return
    fi

    rm -rf $NEW_WORK_DIR
    cp -R --preserve=all "${WORK_DIR}-${ver}" $NEW_WORK_DIR
    cd $NEW_WORK_DIR

    sed -i "s/^#undef intptr_t/\/\/#undef intptr_t/" "./lib/stdint_.h"
    sed -i "s/^#define intptr_t/\/\/#define intptr_t/" "./lib/stdint_.h"

    declare -a patch_list=(
        "src/touch.c"
        "src/copy.c"
        "lib/utimens.h"
        "lib/utimens.c"
    )

    for p in "${patch_list[@]}"
    do
        sed -i "s/futimens/cu_futimens/g" "${p}"
    done

    # Toolchain environment conditionally defines 'AT_FDCWD' variable. Thus, we
    # forcibly used system fcntl.h
    sed -i 's/fcntl.h/linux\/fcntl.h/' "lib/utimens.c"

    echo "$PATCH" | patch -p0 -N > /dev/null

    # DELETE DEFAULT OPTIMAZATION LEVEL
    sed -i "s/-O[s0-9]*//g" "configure"

    doit "$ver" "$comp" "$arch" "$opti" "$NEW_OUTDIR"

    cd ..
    rm -rf $NEW_WORK_DIR
}


mkdir -p $WORK_DIR
cd "${WORK_DIR}"

WORK_DIR="${WORK_DIR}/coreutils"
for ver in "${versions[@]}"
do
    VER_WORK_DIR="${WORK_DIR}-${ver}"
    if [ ! -d "$VER_WORK_DIR" ]; then
        if [ ! -f "coreutils-${ver}.tar.gz" ]; then
            wget "${FTPURL}/coreutils-${ver}.tar.gz"
        fi
        tar zxvf "coreutils-${ver}.tar.gz" > /dev/null
    fi
done

declare -a cmds
declare -i cmd_idx=0
for ver in "${versions[@]}"; do
    for comp in "${compiler_list[@]}"; do
        for arch in "${arch_list[@]}"; do
            for opti in "${opti_list[@]}"; do
                cmds[$cmd_idx]="helper ${ver} ${comp} ${arch} ${opti}"
                #        echo "${cmds[$cmd_idx]}"
                #        eval "${cmds[$cmd_idx]}"
                #        exit
                let cmd_idx++
            done
        done
    done
done

export -f helper
export -f doit
export WORK_DIR
export OUTDIR
export LOGDIR
export SUFFIX
export OPTIONS
export ECHO
export PATCH
export PACKAGE_NAME

echo "${#cmds[@]} options to be processed ..."

parallel -j "$NUM_JOBS" ::: "${cmds[@]}"

