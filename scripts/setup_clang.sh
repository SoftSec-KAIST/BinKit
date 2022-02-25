#!/bin/bash -eu
if [ -z "$TOOL_PATH" ]; then
    echo "env \$TOOL_PATH should be defined first."
    echo "source scripts/env.sh"
    exit
fi

declare -a VERSIONS=(
    # Below versions are used in the paper.
    # "4.0.0"
    # "5.0.0"
    # "6.0.0"
    # "7.0.0"
    # "8.0.0"
    # "9.0.0"

    "4.0.0"
    "5.0.2"
    "6.0.1"
    "7.0.1"
    "8.0.0"
    "9.0.1"
    "10.0.1"
    "11.0.1"
    "12.0.1"
    "13.0.0"
)
SYSNAME="x86_64-linux-gnu-ubuntu-16.04"
CLANG_ROOT="$TOOL_PATH/clang"
LLVM_OBFUS_PATH="$CLANG_ROOT/obfuscator"
CLANG_OBFUS_PATH="$CLANG_ROOT/clang-obfus"

mkdir -p "$CLANG_ROOT"
cd "$CLANG_ROOT"

for VER in "${VERSIONS[@]}"; do
    echo "Setting clang-${VER} =========="
    CLANG_URL="http://releases.llvm.org/${VER}/clang+llvm-${VER}-"
    CLANG_TAR="${CLANG_ROOT}/clang-${VER}.tar.xz"
    CLANG_PATH="${CLANG_ROOT}/clang-${VER%.*}"
    if [[ "${VER%%\.*}" -gt 8 ]]; then
	CLANG_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-${VER}/clang+llvm-${VER}-"
    fi

    if [[ ! -d "$CLANG_PATH" ]]; then
        # If the compilation fails, check if the href contains a correct SYSNAME.
        # For example, the link of 5.0.0 or 5.0.1 contains a SYSNAME,
        # "linux-x86_64-ubuntu16.04" instead of "x86_64-linux-gnu-ubuntu-16.04".
        if [[ ! -f "$CLANG_TAR" ]]; then
            wget "${CLANG_URL}${SYSNAME}.tar.xz" -O "$CLANG_TAR"
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
