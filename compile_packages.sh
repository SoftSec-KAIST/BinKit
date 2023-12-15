#!/bin/bash
# You need to adjust the global variables: BASEDIR, NUM_JOBS, MAX_JOBS
if [ -z "$PROJ_ROOT" ]; then
    echo "env \$PROJ_ROOT should be defined first."
    echo "source scripts/env.sh"
    exit
fi

cd "${PROJ_ROOT}"

# ase18 dataset
BASEDIR="$HOME/data/ase18"
export BASEDIR
NUM_JOBS=8 MAX_JOBS=8 ./do_compile_busybox.sh
NUM_JOBS=8 MAX_JOBS=8 ./do_compile_coreutils_oldv.sh
NUM_JOBS=8 MAX_JOBS=8 ./do_compile_openssl.sh

# gnu packages dataset
BASEDIR="$HOME/data/gnu"
NUM_JOBS=8
MAX_JOBS=8
export NUM_JOBS MAX_JOBS
OPTION=" --base_dir ${BASEDIR} --num_jobs ${NUM_JOBS}"

echo "[*] Dataset installed path: ${BASEDIR}"
read -p "Would you like to continue? [Y/n]: " userInput
if [[ ${userInput,,} == "y" || ${userInput,,} == "" ]]; then
    echo "[+] Download GNU packages ==============="
    python3 gnu_compile_script.py ${OPTION} --download

    # compile normal and sizeopt dataset
    echo "[+] Normal dataset ========================="
    python3 gnu_compile_script.py ${OPTION} --config "config/normal.yml"
    python3 compile_checker.py ${OPTION} --config "config/normal.yml" #--remove

    # Since it is highly likely that other options would be able to compile the same
    # packages, we use whitelist.
    OUTDIR="${BASEDIR}/output_normal"
    ls "${OUTDIR}" |  sort > "${BASEDIR}/whitelist.txt"

    # compile noinline dataset
    echo "[+] Noinline dataset ========================="
    python3 gnu_compile_script.py ${OPTION} --config "config/noinline.yml" --whitelist "${BASEDIR}/whitelist.txt"
    # python3 compile_checker.py ${OPTION} --config "config/noinline.yml" #--remove

    # compile pie dataset
    echo "[+] PIE dataset ========================="
    python3 gnu_compile_script.py ${OPTION} --config "config/pie.yml" --whitelist "${BASEDIR}/whitelist.txt"
    python3 compile_checker.py ${OPTION} --config "config/pie.yml" #--remove

    # compile lto dataset
    echo "[+] LTO dataset ========================="
    python3 gnu_compile_script.py ${OPTION} --config "config/lto.yml" --whitelist "${BASEDIR}/whitelist.txt"
    python3 compile_checker.py ${OPTION} --config "config/lto.yml" #--remove

    # compile obfus dataset
    echo "[+] Obfus dataset ========================="
    python3 gnu_compile_script.py ${OPTION} --config "config/obfus.yml" --whitelist "${BASEDIR}/whitelist.txt"
    python3 compile_checker.py ${OPTION} --config "config/obfus.yml" #--remove
else
    echo "Exiting."
    exit 1
fi
