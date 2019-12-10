# Description
BinKit is a binary code similarity analysis (BCSA) benchmark. BinKit provides
scripts for building a cross-compiling environment, as well as the compiled
dataset. The original dataset includes 1,352 distinct combinations of compiler
options of 8 architectures, 5 optimization levels, and 13 compilers. We
currently tested this code in Ubuntu 16.04.

For more details, please check [our
paper](https://0xdkay.me/pub/2020/kim-arxiv2020.pdf).

# BCSA tool
For a BCSA tool, TikNib, please check
[here](https://github.com/SoftSec-KAIST/TikNib).

## Pre-compiled dataset and toolchain
You can download our dataset and toolchain as below. The link will be changed to
`git-lfs` soon.

[//]: # (Cloning this repository also downloads below pre-compiled dataset and toolchain
with `git-lfs`. Please use `GIT_LFS_SKIP_SMUDGE=1` to skip the download.)

### Dataset
- [Normal dataset](https://drive.google.com/file/d/1K9ef-OoRBr0X5u8g2mlnYqh9o1i6zFij/view?usp=sharing)
- [SizeOpt dataset](https://drive.google.com/file/d/1QgwbEfd8vdzg5glNZFL7dg4l4hrkoWO3/view?usp=sharing)
- [Noinline dataset](https://drive.google.com/file/d/1wt7GY-DDp8J_2zeBBVUrcfWIyerg_xLO/view?usp=sharing)
- [PIE dataset](https://drive.google.com/file/d/1IfEbnS9RtHhVhW8oiqnE7G75uPej1FPx/view?usp=sharing)
- [LTO dataset](https://drive.google.com/file/d/1Tsd-WNO_JDlEX0GylBOxsFjOPUmUyeGh/view?usp=sharing)
- [Obfus dataset](https://drive.google.com/file/d/1H5k3pfJH9zN4anfxKi1WvNqTKmjVjUUU/view?usp=sharing)
- [Obfus 2-Loop dataset](https://drive.google.com/file/d/1C3SXt896R4rJvpvxcItFu9NIgN-hAxz8/view?usp=sharing)

Below data is only used for our evaluation.
- [ASE dataset](https://drive.google.com/file/d/1MwXHRXjuPoQJAON6SZVoKcK6Xr2NMHdF/view?usp=sharing)

### Toolchain
- [tools](https://drive.google.com/file/d/1Ar8CT4xZceT083jMy2dU5q-CgcMHqrQ0/view?usp=sharing)

# Currently supported compile options
### Architecture
- x86_32
- x86_64
- arm_32 (little endian)
- arm_64 (little endian)
- mips_32 (little endian)
- mips_64 (little endian)
- mipseb_32 (big endian)
- mipseb_64 (big endian)

### Optimization
- O0
- O1
- O2
- O3
- Os

### Compilers
- gcc-4.9.4
- gcc-5.5.0
- gcc-6.4.0
- gcc-7.3.0
- gcc-8.2.0
- clang-4.0
- clang-5.0
- clang-6.0
- clang-7.0
- clang-8.0
- clang-9.0
- clang-obfus-fla (Obfuscator-LLVM - FLA)
- clang-obfus-sub (Obfuscator-LLVM - SUB)
- clang-obfus-bcf (Obfuscator-LLVM - BCF)
- clang-obfus-all (Obfuscator-LLVM - FLA + SUB + BCF)

# How to use
### 1. Configure the environment in `scripts/env.sh`
- `NUM_JOBS`: for `make`, `parallel`, and `python` multiprocessing
- `MAX_JOBS`: maximum for `make`

### 2. Build cross-compiling environment (takes lots of time)
We build crosstool-ng and clang environment. If you download pre-compiled
toolchain. Please skip this.

```bash
$ source scripts/env.sh
# We may have missed some packages here ... please check
$ scripts/install_default_deps.sh # install default packages for dataset compilation
$ scripts/setup_ctng.sh       # setup crosstool-ng binaries
$ scripts/setup_gcc.sh        # build ct-ng environment. Takes a lot of time
$ scripts/cleanup_ctng.sh     # cleaning up ctng leftovers
$ scripts/setup_clang.sh      # setup clang and llvm-obfuscator
```

### 3. Link toolchains
```bash
$ scripts/link_toolchains.sh  # link base toolchain
```
To undo the linking, please check `scripts/unlink_toolchains.sh`

### 4. Build dataset
Please configure variables in `compile_packages.sh` and run below. *NOTE* that
some combination of options would not be compiled.

```/bin/bash
$ scripts/install_gnu_deps.sh # install default packages for dataset compilation
$ ./compile_packages.sh
```

# Authors
This project has been conducted by the below authors at KAIST.
* [Dongkwan Kim](https://0xdkay.me/)
* [Eunsoo Kim](https://hahah.kim)
* [Sang Kil Cha](https://softsec.kaist.ac.kr/~sangkilc/)
* [Sooel Son](https://sites.google.com/site/ssonkaist/home)
* [Yongdae Kim](https://syssec.kaist.ac.kr/~yongdaek/)

# Citation
We would appreciate if you consider citing [our
paper](https://0xdkay.me/pub/2020/kim-arxiv2020.pdf) when using BinKit.
```bibtex
@article{kim:2020:binkit,
  author = {Dongkwan Kim and Eunsoo Kim and Sang Kil Cha and Sooel Son and Yongdae Kim},
  title = {Revisiting Binary Code Similarity Analysis using Interpretable Feature Engineering and Lessons Learned},
  eprint={2011.10749},
  archivePrefix={arXiv},
  primaryClass={cs.SE}
  year = {2020},
}
```
