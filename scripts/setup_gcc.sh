#!/bin/bash
if [ -z "$CTNG_BIN" ]; then
    echo "env \$CTNG_BIN should be defined first."
    echo "source scripts/env.sh"
    exit
fi

tmp_list=$(find "$CTNG_CONF_PATH" -mindepth 1 -maxdepth 1 -type d)
mapfile -t VERSION_LIST <<< "${tmp_list}"

function doit()
{
    local DIRNAME=$1
    cd "$DIRNAME"

    # gcc-6.4.0 has a bug. We need to fix this
    # https://gcc.gnu.org/viewcvs/gcc/trunk/libgcc/config/i386/linux-unwind.h?r1=249731&r2=249730&pathrev=249731
    if [[ $DIRNAME =~ 6.4 ]]; then
        echo "Preparing $DIRNAME ..."
        ${CTNG_BIN} -s -j ${NUM_JOBS} -l ${MAX_JOBS} build STOP=companion_tools_for_build
        find "$DIRNAME" -type f -name "linux-unwind.h" | xargs sed -i "s/struct ucontext/ucontext_t/"
        ${CTNG_BIN} -s -j ${NUM_JOBS} -l ${MAX_JOBS} build RESTART=companion_tools_for_build
    else
        ${CTNG_BIN} -s -j ${NUM_JOBS} -l ${MAX_JOBS} build
    fi

    rm -rf "$DIRNAME/.build"
}

declare -a cmds
declare -i cmd_idx=0
for VER in "${VERSION_LIST[@]}"; do
    tmp_list=$(find "${VER}" -maxdepth 1 -mindepth 1 -type f -name "*.conf")
    mapfile -t CONF_LIST <<< "${tmp_list}"
    for CONF in "${CONF_LIST[@]}"; do
        # Use glibc version 2.26
        sed -i "s/CT_GLIBC_V_2_27=y/# CT_GLIBC_V_2_27 is not set/g" "$CONF"
        sed -i "s/# CT_GLIBC_V_2_26 is not set/CT_GLIBC_V_2_26=y/g" "$CONF"
        sed -i "s/CT_GLIBC_VERSION=\"2.27\"/CT_GLIBC_VERSION=\"2.26\"/g" "$CONF"
        sed -i "s/CT_GLIBC_2_27_or_later=y/CT_GLIBC_older_than_2_27=y/g" "$CONF"
        sed -i "s/CT_GLIBC_later_than_2_26=y/CT_GLIBC_2_26_or_older=y/g" "$CONF"

        #    # Use multilib
        #    sed -i "s/# CT_MULTILIB is not set/CT_MULTILIB=y/g" "$CONF"
        #    sed -i "s/CT_DEMULTILIB=y/CT_CC_GCC_MULTILIB_LIST=\"\"/g" "$CONF"

        # Do not use multilib
        sed -i "s/CT_MULTILIB=y/# CT_MULTILIB is not set/g" "$CONF"
        sed -i "s/CT_CC_GCC_MULTILIB_LIST=\"\"/CT_DEMULTILIB=y/g" "$CONF"

        # Set target vendor to ubuntu
        sed -i "s/CT_TARGET_VENDOR=\"ubuntu18.04\"/CT_TARGET_VENDOR=\"ubuntu\"/g" "$CONF"
        sed -i "s/CT_TARGET_VENDOR=\"ubuntu16.04\"/CT_TARGET_VENDOR=\"ubuntu\"/g" "$CONF"
        sed -i "s/CT_TARGET_VENDOR=\"ubuntu14.04\"/CT_TARGET_VENDOR=\"ubuntu\"/g" "$CONF"

        # Set output paths
        sed -i "s/CT_PREFIX_DIR=\"\${CT_PREFIX:-\${HOME}\/x-tools}\/\${CT_HOST:+HOST-\${CT_HOST}\/}\${CT_TARGET}\"/CT_PREFIX_DIR=\"\${CT_PREFIX:-\${HOME}\/x-tools}\/\${CT_HOST:+HOST-\${CT_HOST}\/}\${CT_TARGET}-\${CT_GCC_VERSION}\"/" "$CONF"
        sed -i "s/\${HOME}\/x-tools/\${TOOL_PATH}/" "$CONF"
        sed -i "s/\${HOME}\/src/\${TOOL_PATH}\/ctng_tarballs/" "$CONF"

        # Set log level to error
        sed -i "s/CT_LOG_EXTRA=y/# CT_LOG_EXTRA is not set/" "$CONF"
        sed -i "s/# CT_LOG_ERROR is not set/CT_LOG_ERROR=y/" "$CONF"
        sed -i "s/CT_LOG_LEVEL_MAX=\"EXTRA\"/CT_LOG_LEVEL_MAX=\"ERROR\"/" "$CONF"

        if [[ $VER =~ 6.4 ]]; then
            # Save debug steps
            sed -i 's/# CT_DEBUG_CT is not set/CT_DEBUG_CT=y\n# CT_DEBUG_PAUSE_STEPS is not set\nCT_DEBUG_CT_SAVE_STEPS=y\nCT_DEBUG_CT_SAVE_STEPS_GZIP=y\n# CT_DEBUG_INTERACTIVE is not set/' "$CONF"
        else
            sed -i 's/CT_DEBUG_CT=y/# CT_DEBUG_CT is not set/' "$CONF"
            sed -i 's/CT_DEBUG_CT_SAVE_STEPS=y/# CT_DEBUG_CT_SAVE_STEPS is not set/' "$CONF"
            sed -i 's/CT_DEBUG_CT_SAVE_STEPS_GZIP=y/# CT_DEBUG_CT_SAVE_STEPS_GZIP is not set/' "$CONF"
        fi

        #    # Set static compile
        #    sed -i "s/# CT_STATIC_TOOLCHAIN is not set/CT_STATIC_TOOLCHAIN=y/" "$CONF"

        # Unset static compile
        sed -i "s/CT_STATIC_TOOLCHAIN=y/# CT_STATIC_TOOLCHAIN is not set/" "$CONF"

        #    # Check configuration manually
        #    CUR="$PWD"
        #    cd "$DIRNAME"
        #    ${CTNG_BIN} show-config
        #    cd "$CUR"

        DIRNAME=${CONF%.conf}
        mkdir -p "$DIRNAME"
        cp "$CONF" "$DIRNAME/.config"

        #    # To download default tarballs
        #    setup "$DIRNAME"

        cmds[$cmd_idx]="$DIRNAME"
        let cmd_idx++
    done
done

export -f doit
echo "${#cmds[@]} builds to be processed ..."
time parallel -j 15 doit ::: "${cmds[@]}"

