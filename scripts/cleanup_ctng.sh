#!/bin/bash
if [ -z "$CTNG_CONF_PATH" ]; then
    echo "env \$CTNG_CONF_PATH should be defined first."
    echo "source scripts/env.sh"
    exit
fi

find "$CTNG_CONF_PATH" -mindepth 2 -maxdepth 2 -type d -exec rm -rf {} \;
