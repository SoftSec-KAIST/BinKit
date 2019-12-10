#!/bin/bash
if [ -z "$TOOL_PATH" ]; then
    echo "env \$TOOL_PATH should be defined first."
    echo "source scripts/env.sh"
    exit
fi

# setup crosstool-ng
CTNG_BIN="$TOOL_PATH/crosstool-ng/ct-ng"
CTNG_PATH="$TOOL_PATH/crosstool-ng"
if [ ! -f "$CTNG_BIN" ]; then
    if [ ! -d "$CTNG_PATH" ]; then
        git clone "https://github.com/crosstool-ng/crosstool-ng" "$CTNG_PATH"
    fi
    cd "$CTNG_PATH"
    make distclean
    ./bootstrap
    ./configure --enable-local
    make -j "${NUM_JOBS}" -l "${MAX_JOBS}"
fi
export CTNG_BIN
export CTNG_PATH
