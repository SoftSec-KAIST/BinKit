#!/bin/bash

# ------- get arguments ------------------------
PACKAGE_NAME=${1}
TAR_NAME=${2}
WORK_DIR=${3}

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

function do_extract {
    FILE=$1
    TAR_NAME=$2
    PACK=$3

    if [ ! -z "${PACK}" ]; then
        FILE=$3
        TAR_DIR=" -C ${PACK} "
        mkdir -p $PACK
    fi

    # if tar file is already decompressed, stop
    if [[ -d $FILE ]]; then
        return
    elif [[ -e $FILE ]]; then
        return
    fi

    tar x$TAR_OPT $TAR_NAME $TAR_DIR > /dev/null
}

# set working directory
TAR_ROOT=`tar t${TAR_OPT} "${TAR_NAME}" | sed -e 's@/.*@@' | uniq`
if [ -z $TAR_ROOT ]; then
    echo "${PACKAGE_NAME} got something wrong"
    exit
fi

if [[ $TAR_ROOT == "." ]]; then
    # if no root directory
    TAR_ROOT=$PACKAGE_NAME
    do_extract $TAR_ROOT $TAR_NAME $PACKAGE_NAME
else
    # if root directory exists
    do_extract $TAR_ROOT $TAR_NAME
fi

if [[ ! -d $TAR_ROOT ]]; then
    echo "${PACKAGE_NAME} has no root ..."
    exit
fi

