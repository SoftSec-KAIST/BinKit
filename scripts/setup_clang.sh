#!/bin/bash
if [ -z "$TOOL_PATH" ]; then
    echo "env \$TOOL_PATH should be defined first."
    echo "source scripts/env.sh"
    exit
fi

declare -a VERSIONS=(
    "4.0"
    "5.0"
    "6.0"
    "7.0"
    "8.0"
    "9.0"
)
SYSNAME="x86_64-linux-gnu-ubuntu-16.04"
CLANG_ROOT="$TOOL_PATH/clang"
LLVM_OBFUS_PATH="$CLANG_ROOT/obfuscator"
CLANG_OBFUS_PATH="$CLANG_ROOT/clang-obfus"

mkdir -p "$CLANG_ROOT"
cd "$CLANG_ROOT"

for VER in "${VERSIONS[@]}"; do
    echo "Setting clang-${VER} =========="
    CLANG_URL="http://releases.llvm.org/${VER}.0/clang+llvm-${VER}.0-"
    CLANG_TAR="${CLANG_ROOT}/clang-${VER}.tar.xz"
    CLANG_PATH="${CLANG_ROOT}/clang-${VER}"

    if [[ ! -d "$CLANG_PATH" ]]; then
        if [[ ! -f "$CLANG_TAR" ]]; then
            if [[ "$VER" =~ 5.0 ]]; then
                wget "${CLANG_URL}linux-x86_64-ubuntu16.04.tar.xz" -O "$CLANG_TAR"
            else
                wget "${CLANG_URL}${SYSNAME}.tar.xz" -O "$CLANG_TAR"
            fi
        fi

        CLANG_VER_DIR=$(tar tf ${CLANG_TAR} | head -n 1)
        tar xf "${CLANG_TAR}"
        mv "$CLANG_VER_DIR" "$CLANG_PATH"
    fi
done

if [[ ! -d "$LLVM_OBFUS_PATH" ]]; then
    git clone -b llvm-4.0 https://github.com/obfuscator-llvm/obfuscator.git
fi

if [[ ! -d "$CLANG_OBFUS_PATH" ]]; then
    mkdir -p "$CLANG_OBFUS_PATH"
    cd "$CLANG_OBFUS_PATH"
    # Setup llvm obfuscator
    cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DLLVM_INCLUDE_TESTS=OFF ../obfuscator
    make -j ${NUM_JOBS} -l ${MAX_JOBS}
    cd ..

    ln -s ./clang-obfus ./clang-obfus-fla
    ln -s ./clang-obfus ./clang-obfus-sub
    ln -s ./clang-obfus ./clang-obfus-bcf
    ln -s ./clang-obfus ./clang-obfus-all
    ln -s ./clang-obfus ./clang-obfus-all-2
fi
