#!/bin/bash
# Setup default tool path. All tools will be located here.
PROJ_ROOT="${PWD}"
TOOL_PATH="${PROJ_ROOT}/tools/"
export PROJ_ROOT TOOL_PATH
mkdir -p "$TOOL_PATH"

CTNG_BIN="$TOOL_PATH/crosstool-ng/ct-ng"
CTNG_PATH="$TOOL_PATH/crosstool-ng"
CTNG_CONF_PATH="$PROJ_ROOT/ctng_conf"
CTNG_TARBALL_PATH="$TOOL_PATH/ctng_tarballs"
EXTRA_DEP_PATH="$TOOL_PATH/extra_dep"
export CTNG_CONF_PATH CTNG_BIN CTNG_PATH CTNG_TARBALL_PATH EXTRA_DEP_PATH
mkdir -p "$CTNG_TARBALL_PATH"

NUM_JOBS=8
MAX_JOBS=8
export NUM_JOBS MAX_JOBS
