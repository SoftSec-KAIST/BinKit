#!/bin/bash

SOURCE_GIT_PATH="https://git.busybox.net/busybox"
WORK_DIR="$BASEDIR/sources/busybox"
OUTDIR="$BASEDIR/output/busybox"
LOGDIR="$BASEDIR/logs/busybox"
PACKAGE_NAME="busybox"

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

declare -a unused_arch_list=(
    "ppc_32"
    "ppc_64"
)

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

#declare -a versions=("master")
#declare -a versions=("1_26_stable")
declare -a versions=("1_21_stable")

PATCH=$(<patches/busybox_121_mips_dwarf2out.patch)

function doit()
{
    local VER=$1
    local COMPILER=$2
    local ARCH=$3
    local OPT=$4
    local OPTIONS="${OPTIONS}"
    local EXTRA="${EXTRA}"

    make clean >/dev/null 2>/dev/null
    make defconfig > /dev/null 2>/dev/null

    # nested loop is not supported by clang
    sed -i 's/CONFIG_FIND=y/# CONFIG_FIND is not set/' ".config"

    # z stream error for clang
    sed -i 's/# CONFIG_FEATURE_SEAMLESS_Z is not set/CONFIG_FEATURE_SEAMLESS_Z=y/' ".config"

    # debug option
    sed -i 's/# CONFIG_DEBUG is not set/CONFIG_DEBUG=y/' ".config"

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
    ARCH_POWERPC="powerpc-ubuntu-linux-gnu"
    ARCH_POWERPC64="powerpc64-ubuntu-linux-gnu"

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
    elif [[ $ARCH == "ppc_32" ]]; then
        ARCH_PREFIX=$ARCH_POWERPC
    elif [[ $ARCH == "ppc_64" ]]; then
        ARCH_PREFIX=$ARCH_POWERPC64
    fi

    export PATH="${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}/bin:${PATH}"
    SYSROOT="${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}/${ARCH_PREFIX}/sysroot"
    SYSTEM="${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}/${ARCH_PREFIX}/sysroot/usr/include"

    OPTIONS="${OPTIONS} -${OPT}"
    if [[ $COMPILER =~ "gcc" ]]; then
        CMD=""
        CMD="CROSS_COMPILE=\"${ARCH_PREFIX}-\""
        CMD="${CMD} CFLAGS=\" ${OPTIONS}"
        CMD="${CMD} -isysroot ${SYSROOT} -isystem ${SYSTEM} -I${SYSTEM}\""
        CMD="${CMD} LDFLAGS=\"${OPTIONS}\""
        CMD="${CMD} AR=\"${ARCH_PREFIX}-gcc-ar\""
        CMD="${CMD} RANLIB=\"${ARCH_PREFIX}-gcc-ranlib\""
        CMD="${CMD} NM=\"${ARCH_PREFIX}-gcc-nm\""

    elif [[ $COMPILER =~ "clang" ]]; then
        CMD="CC=\"clang --target=${ARCH_PREFIX}\""
        CMD="${CMD} CROSS_COMPILE=\"${ARCH_PREFIX}-\""
        CMD="${CMD} CFLAGS=\" ${OPTIONS} ${EXTRA} --target=${ARCH_PREFIX}"
        CMD="${CMD} --gcc-toolchain=${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}"
        CMD="${CMD} -isysroot ${SYSROOT} -isystem ${SYSTEM} -I${SYSTEM}\""
        CMD="${CMD} LDFLAGS=\"${OPTIONS}\""
        CMD="${CMD} AR=\"llvm-ar\""
        CMD="${CMD} RANLIB=\"llvm-ranlib\""
        CMD="${CMD} NM=\"llvm-nm\""
    fi
    CMD="make -j ${NUM_JOBS} -l ${MAX_JOBS} ${CMD}"

    if ! $ECHO; then
        COMPILETYPE="${COMPILER}_${ARCH}_${OPT}"
        MAKEDIR="${LOGDIR}/make/"
        CMD="${CMD} >${MAKEDIR}/${PACKAGE_NAME}-${VER}_${COMPILETYPE}${SUFFIX}_make_error.log 2>&1"
    fi

    if [ -f Makefile ]; then
        # one should wrap variables with "" ...
        sed -i 's/ CC=\$\${CC:-\$(CC)}/ CC="\$\${CC:-\$(CC)}"/' Makefile
        sed -i 's/ CC=\$(CC)/ CC="$(CC)"/' Makefile
    fi

    eval "${CMD}"


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
        "./busybox_unstripped"
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
    cp -R --preserve=all $WORK_DIR $NEW_WORK_DIR
    cd $NEW_WORK_DIR

    eval "git checkout -- . >/dev/null 2>&1"
    eval "git checkout $ver >/dev/null 2>&1"

    # DELETE DEFAULT OPTIMAZATION LEVEL
    #sed -i "s/-O[0-9]*//g" "configure"

    #  if [[ $ver == "1_21_stable" ]]; then
    #    echo "$PATCH" | patch -p0 -N > /dev/null
    #  fi

    doit "$ver" "$comp" "$arch" "$opti" "$NEW_OUTDIR"

    cd ..
    rm -rf $NEW_WORK_DIR
}

#echo $WORK_DIR
if [ ! -d "$WORK_DIR" ]; then
    git clone $SOURCE_GIT_PATH $WORK_DIR
fi
mkdir -p $OUTDIR

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

