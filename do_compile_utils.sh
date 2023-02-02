#!/bin/bash

# ========= NOTES ===================
# if not use lld
# -> flto cannot be compiled
# if use lld
# -> pie link error to readonly section for mips_32, mipseb_32

# TODO: add VER to the final binary name after PACKAGE_NAME

# ------- get arguments ------------------------
PACKAGE_NAME=${1}
TAR_NAME=${2}
VER=${3}
WORK_DIR=${4}
OUTDIR=${5}
LOGDIR=${6}
OPTI_LEVEL=${7}
ARCH=${8}
COMPILER=${9}
SUFFIX=${10}
ECHOON=${11}
mkdir -p $LOGDIR

COMPILETYPE="${COMPILER}_${ARCH}_${OPTI_LEVEL}"
CONFIGSUB=$(<patches/config.sub)

## ------ check already exists ----------------
#files=`find "${OUTDIR}" -executable -type f -name "${PACKAGE_NAME}*_${COMPILETYPE}_*"`
#if [ ! -z "${files// }" ]; then
#  exit
#fi

# ------- check default ----------------------
cd $WORK_DIR

if [ -f $TAR_NAME ] ; then
    case $TAR_NAME in
        *.tar.bz2)  TAR_OPT="jf"   ;;
        *.tar.gz)   TAR_OPT="zf"   ;;
        *.tar.xz)   TAR_OPT="f"   ;;
        *.txz)      TAR_OPT="f"   ;;
        *.tar)      TAR_OPT="f"    ;;
        *.tbz2)     TAR_OPT="jf"   ;;
        *.tgz)      TAR_OPT="zf"   ;;
        *)          echo "'$TAR_NAME' cannot be extracted via extract()"; exit ;;
    esac
else
    echo "'$TAR_NAME' is not a valid file"
    exit
fi

# set working directory
TAR_ROOT=`tar t${TAR_OPT} "${TAR_NAME}" | sed -e 's@/.*@@' | uniq`
if [ -z $TAR_ROOT ]; then
    echo "${PACKAGE_NAME} got something wrong"
    exit
fi

if [[ $TAR_ROOT == "." ]]; then
    # if no root directory
    TAR_ROOT=$PACKAGE_NAME
fi

if [[ ! -d $TAR_ROOT ]]; then
    echo "${PACKAGE_NAME} has no root ..."
    exit
fi

function do_compile()
{
    local CCTARGET=$1
    local AUTOCONF=$2
    LOGPREFIX="${PACKAGE_NAME}-${VER}_${COMPILETYPE}${SUFFIX}"

    if [ ! -z "$CCTARGET" ] || [ ! -z "$AUTOCONF" ]; then
        if [ ! $CNT -eq "0" ]; then
            return
        else
            LOGPREFIX="${PACKAGE_NAME}-${VER}_${COMPILETYPE}${SUFFIX}_${CCTARGET}_${AUTOCONF}"
        fi
    fi

    # ------------------- compile with CC="clang --target=" -----------------
    # clang needs to compile with this ...
    if [[ $CCTARGET == "CCTARGET" ]] && [[ ! $COMPILER =~ "clang" ]]; then
        return
    fi

    NEW_WORK_DIR="${TAR_ROOT}_${COMPILETYPE}${SUFFIX}"
    # remove directory and copy again
    rm -rf "${NEW_WORK_DIR}"
    if [ ! -d "$NEW_WORK_DIR" ]; then
        cp -R --preserve=all $TAR_ROOT $NEW_WORK_DIR
    fi
    cd $NEW_WORK_DIR


    if [ ! -f "configure" ]; then
        cd ..
        rm -rf $NEW_WORK_DIR
        exit
    fi

    # need to add aarch64 to config.sub
    #if [[ $ARCH =~ "arm_64" ]]; then
    subfile=`find . -name "config.sub" 2>/dev/null`
    mapfile -t subfiles <<< "${subfile}"
    for sub in "${subfiles[@]}"; do
        if [[ -f "${sub}" ]]; then
            chmod 755 ${sub}
            echo "${CONFIGSUB}" > ${sub}
        fi
    done
    #fi

    # ------- check architecture ------------------
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

    local OPTIONS=""
    local EXTRA_CFLAGS=""
    local EXTRA_LDFLAGS=""

    # for debugging information
    # -fno-var-tracking due to gcc-4.9.4 O1 dwarf2out
    OPTIONS="${OPTIONS} -g -fno-var-tracking"

    # ------- check inline, pie, lto options -----
    if [[ $SUFFIX =~ "noinline" ]]; then
        OPTIONS="${OPTIONS} -fno-inline"
    fi

    if [[ $SUFFIX =~ "pie" ]]; then
        OPTIONS="${OPTIONS} -pie -fPIE"

        # we will not consider giving nostartfiles option since this corrupt the
        # section and yields corrupted elf binary.
        #    if [[ $PACKAGE_NAME =~ "coreutils" ]]; then
        #      EXTRA_LDFLAGS="-nostartfiles"
        #    fi
    fi

    if [[ $SUFFIX =~ "lto" ]]; then
        OPTIONS="${OPTIONS} -flto"
    fi

    if [[ $COMPILER =~ "gcc" ]]; then
        COMPVER=${COMPILER#"gcc-"}

    elif [[ $COMPILER =~ "clang" ]]; then
        # using LLVM-obfuscator
        if [[ $COMPILER =~ "obfus" ]]; then
            OBFUS=${COMPILER#clang-obfus-}
            if [[ $OBFUS =~ "all-2" ]]; then
                EXTRA_CFLAGS="${EXTRA_CFLAGS} -mllvm -fla -mllvm -split -mllvm -split_num=2 -mllvm -sub -mllvm -sub_loop=2 -mllvm -bcf -mllvm -bcf_loop=2"
            elif [[ $OBFUS =~ "all" ]]; then
                EXTRA_CFLAGS="${EXTRA_CFLAGS} -mllvm -fla -mllvm -sub -mllvm -bcf"
            else
                EXTRA_CFLAGS="${EXTRA_CFLAGS} -mllvm -${OBFUS}"
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

    if [[ $ARCH =~ "eb_" ]]; then
        OPTIONS="${OPTIONS} -EB"
    fi

    # ========= x86 =============
    if [ $ARCH == "x86_32" ]; then
        ARCH_PREFIX=$ARCH_X86
        OPTIONS="${OPTIONS} -m32"
        ELFTYPE="ELF 32-bit LSB"
        ARCHTYPE="Intel 80386"

    elif [ $ARCH == "x86_64" ]; then
        ARCH_PREFIX=$ARCH_X8664
        ELFTYPE="ELF 64-bit LSB"
        ARCHTYPE="x86-64"

        # ========= arm =============
    elif [ $ARCH == "arm_32" ]; then
        ARCH_PREFIX=$ARCH_ARM
        ELFTYPE="ELF 32-bit LSB"
        ARCHTYPE="ARM, EABI5"

    elif [ $ARCH == "arm_64" ]; then
        ARCH_PREFIX=$ARCH_ARM64
        ELFTYPE="ELF 64-bit LSB"
        ARCHTYPE="ARM aarch64"

        # ========= mips =============
    elif [ $ARCH == "mips_32" ]; then
        ARCH_PREFIX=$ARCH_MIPS
        OPTIONS="${OPTIONS} -mips32r2"
        ELFTYPE="ELF 32-bit LSB"
        #ARCHTYPE="MIPS, MIPS32 rel2"
        ARCHTYPE="MIPS, MIPS32"

    elif [ $ARCH == "mips_64" ]; then
        ARCH_PREFIX=$ARCH_MIPS64
        OPTIONS="${OPTIONS} -mips64r2"
        ELFTYPE="ELF 64-bit LSB"
        #ARCHTYPE="MIPS, MIPS64 rel2"
        ARCHTYPE="MIPS, MIPS64"

        # ========= mipseb =============
    elif [ $ARCH == "mipseb_32" ]; then
        ARCH_PREFIX=$ARCH_MIPSEB
        OPTIONS="${OPTIONS} -mips32r2"
        ELFTYPE="ELF 32-bit MSB"
        #ARCHTYPE="MIPS, MIPS32 rel2"
        ARCHTYPE="MIPS, MIPS32"

    elif [ $ARCH == "mipseb_64" ]; then
        ARCH_PREFIX=$ARCH_MIPSEB64
        OPTIONS="${OPTIONS} -mips64r2"
        ELFTYPE="ELF 64-bit MSB"
        #ARCHTYPE="MIPS, MIPS64 rel2"
        ARCHTYPE="MIPS, MIPS64"

        # ========= powerpc =============
    elif [[ $ARCH == "ppc_32" ]]; then
        ARCH_PREFIX=$ARCH_POWERPC
        ELFTYPE="ELF 32-bit MSB"
	ARCHTYPE="PowerPC or cisco 4500"

    elif [[ $ARCH == "ppc_64" ]]; then
        ARCH_PREFIX=$ARCH_POWERPC64
        ELFTYPE="ELF 64-bit MSB"
	ARCHTYPE="64-bit PowerPC or cisco 7500"
    fi

    export PATH="${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}/bin:${PATH}"
    SYSROOT="${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}/${ARCH_PREFIX}/sysroot"
    SYSTEM="${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER}/${ARCH_PREFIX}/sysroot/usr/include"

    EXTRA_CFLAGS="${EXTRA_CFLAGS} -fcommon"

    if [ $ARCH == "x86_64" ]; then
        local EXTRA_LDFLAGS="-L${EXTRA_DEP_PATH}/install_x86_64/lib -luuid"
    fi

    OPTIONS="${OPTIONS} -${OPTI_LEVEL}"
    if [[ $COMPILER =~ "gcc" ]]; then
        CMD=""
        CMD="--host=\"${ARCH_PREFIX}\""
        CMD="${CMD} CFLAGS=\""
        CMD="${CMD} -isysroot ${SYSROOT} -isystem ${SYSTEM} -I${SYSTEM}"
        CMD="${CMD} ${OPTIONS}\""
        CMD="${CMD} LDFLAGS=\"${OPTIONS} ${EXTRA_LDFLAGS}\""
        CMD="${CMD} AR=\"${ARCH_PREFIX}-gcc-ar\""
        CMD="${CMD} RANLIB=\"${ARCH_PREFIX}-gcc-ranlib\""
        CMD="${CMD} NM=\"${ARCH_PREFIX}-gcc-nm\""

    elif [[ $COMPILER =~ "clang" ]]; then
        CMD="--host=\"${ARCH_PREFIX}\""

        # ------------------- compile with CC="clang --target=" -----------------
        # clang needs to compile with this ...
        if [[ $CCTARGET == "CCTARGET" ]]; then
            CMD="${CMD} CC=\"clang --target=${ARCH_PREFIX}"
            CMD="${CMD} --gcc-toolchain=${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER} \""
            CMD="${CMD} CFLAGS=\" "
        else
            CMD="${CMD} CC=\"clang\""
            CMD="${CMD} CFLAGS=\" --target=${ARCH_PREFIX}"
            CMD="${CMD} --gcc-toolchain=${TOOL_PATH}/${ARCH_PREFIX}-${COMPVER} "
        fi
        CMD="${CMD} -isysroot ${SYSROOT} -isystem ${SYSTEM} -I${SYSTEM}"
        CMD="${CMD} ${OPTIONS} ${EXTRA_CFLAGS}\""
        CMD="${CMD} LDFLAGS=\"${OPTIONS} ${EXTRA_LDFLAGS}\""
        CMD="${CMD} AR=\"llvm-ar\""
        CMD="${CMD} RANLIB=\"llvm-ranlib\""
        CMD="${CMD} NM=\"llvm-nm\""
    fi

    # coreutils time_t force to 32-bit
    if [[ $ARCH =~ "_32" ]]; then
        if [[ $PACKAGE_NAME =~ (coreutils|gzip) ]]; then
            CMD="${CMD} TIME_T_32_BIT_OK=yes"
        fi
    fi


    AUTO="autoconf"
    #CONF="./configure --build=x86_64-linux-gnu ${CMD}"
    # install output binaries in a temporary directory (--prefix)
    CONF="./configure --prefix=\"${PWD}/gogo\" --build=x86_64-linux-gnu ${CMD}"
    MAKE="make -j ${NUM_JOBS} -l ${MAX_JOBS}"
    # make install to filter out unnecessary elf files
    INS="make install"
    if [[ $ECHOON == "False" ]]; then
        AUTO="${AUTO} >${LOGDIR}/${LOGPREFIX}_autoconf.log"
        AUTO="${AUTO} 2>${LOGDIR}/${LOGPREFIX}_autoconf_error.log"
        CONF="${CONF} >${LOGDIR}/${LOGPREFIX}_configure.log"
        CONF="${CONF} 2>${LOGDIR}/${LOGPREFIX}_configure_error.log"
        MAKE="${MAKE} >${LOGDIR}/${LOGPREFIX}_make.log"
        MAKE="${MAKE} 2>${LOGDIR}/${LOGPREFIX}_make_error.log"
        INS="${INS} >${LOGDIR}/${LOGPREFIX}_install.log"
        INS="${INS} 2>${LOGDIR}/${LOGPREFIX}_install_error.log"
    fi


    # -------- now start compiling! -------------
    #echo "[+] running $VER $COMPILER $ARCH $OPT ----"

    if [[ $AUTOCONF == "AUTOCONF" ]]; then
        # autoconf
        eval $AUTO
    fi

    # DELETE DEFAULT OPTIMAZATION LEVEL
    sed -i "s/-O[s0-9]*//g" "configure"

    # configure
    eval $CONF

    if [ -f Makefile ]; then
        # one should wrap variables with "" ...
        sed -i 's/ CC=\$\${CC:-\$(CC)}/ CC="\$\${CC:-\$(CC)}"/' Makefile
        sed -i 's/ CC=\$(CC)/ CC="$(CC)"/' Makefile
    fi

    # make
    eval $MAKE

    # make install
    eval $INS

    # -------- file check -----------------
    CNT=0
    # for debug
    #tmp_list=`find . -type f -executable -exec file {} \; 2>/dev/null \
    # check output binaries in the temporary directory (previously, --prefix)
    tmp_list=`find "${PWD}/gogo" -type f -executable -exec file {} \; 2>/dev/null \
        | grep -v "ERROR" \
        | grep "${ELFTYPE}" | grep "${ARCHTYPE}" \
        | cut -d ":" -f 1 | grep -v "\\.o$"`
    mapfile -t bin_list <<< "${tmp_list}"
    BINS=""
    for b in "${bin_list[@]}"
    do
        # filter known directories that do not belong to output binaries
        if [[ ! -z "${b// }" ]] \
            && [[ ! "${b}" =~ (/extension/|/gettext-tools/|/contrib/|/test/) ]] \
            && [[ ! "${b}" =~ (/testsuite/|/modules/|/builtins/|/support/) ]] \
            && [[ ! "${b}" =~ (/tests/|/examples/|/doc/|/po/) ]]; then
            #&& [[ ! "${b}" =~ test ]]; then
            mkdir -p "${OUTDIR}"
            cp "${b}" "${OUTDIR}/${PACKAGE_NAME}-${VER}_${COMPILETYPE}_${b##*/}"
            CNT=$((CNT + 1))
            BINS="${BINS}${b}\n"
        fi
    done

    if [ "$CNT" -gt "0" ]; then
        OUTSTR="${LOGPREFIX}: COMPILE SUCCESS!!"
        touch "${LOGDIR}/${LOGPREFIX}_success"

    else
        OUTSTR="${LOGPREFIX}: COMPILE FAIL."
        touch "${LOGDIR}/${LOGPREFIX}_fail"

        if [ -f config.log ]; then
            cp config.log "${LOGDIR}/${LOGPREFIX}_config.log"
        fi
    fi

    if [[ $ECHOON == "True" ]]; then
        echo -e "${OUTSTR}";
    fi

    cd ..
    rm -rf "${NEW_WORK_DIR}"
}

# TODO: move timeout script here
#function check_timeout()
#{
#  eval "timeout $1 $2 $3 $4"
#  exit_status=$?
#  if [[ "$exit_status" -eq "124" ]]; then
#    touch "${LOGDIR}/${LOGPREFIX}_timeout"
#  fi
#}

CNT=0

# Hope one of below would work. If there exists a compiled binary after one, we
# do not proceed more. The CNT variable reprsents the number of compiled
# binaries.
do_compile "" ""
do_compile "" "AUTO"
do_compile "CCTARGET" ""
do_compile "CCTARGET" "AUTO"

