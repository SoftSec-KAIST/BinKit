# Description
BinKit is a binary code similarity analysis (BCSA) benchmark. BinKit provides
scripts for building a cross-compiling environment, as well as the compiled
dataset. The original dataset includes 1,352 distinct combinations of compiler
options of 8 architectures, 5 optimization levels, and 13 compilers. We
currently tested this code in Ubuntu 16.04.

For more details, please check [our
paper](https://0xdkay.me/pub/2020/kim-arxiv2020.pdf).

# BCSA tool and Ground Truth Building
For a BCSA tool and ground truth building, please check
[TikNib](https://github.com/SoftSec-KAIST/TikNib).

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
Please configure variables in `compile_packages.sh` and run below. The script
automatically downloads the source code of GNU packages, and compiles them to
make all the dataset. However, it may take too much time to create all of them.

- *NOTE* that it takes *SIGNIFIACNT* time.
- *NOTE* that some packages would not be compiled for some compiler options.

```bash
$ scripts/install_gnu_deps.sh # install default packages for dataset compilation
$ ./compile_packages.sh
```

### 4-1. Build dataset (manual)

You can download the source code of GNU packages of your interest as below.
- Please check step 1 before running the command.
- You must give *ABSOLUTE PATH* for `--base_dir`.

```bash
$ source scripts/env
$ python gnu_compile_script.py \
    --base_dir "/home/dongkwan/binkit/dataset/gnu" \
    --num_jobs 8 \
    --whitelist "config/whitelist.txt" \
    --download
```

You can compile only the packages or compiler options of your interest as below.

```bash
$ source scripts/env
$ python gnu_compile_script.py \
    --base_dir "/home/dongkwan/binkit/dataset/gnu" \
    --num_jobs 8 \
    --config "config/normal.yml" \
    --whitelist "config/whitelist.txt"
```

You can check the compiled binaries as below.

```bash
$ source scripts/env
$ python compile_checker.py \
    --base_dir "/home/dongkwan/binkit/dataset/gnu" \
    --num_jobs 8 \
    --config "config/normal.yml"
```

For more details, please check `compile_packages.sh`

### 4-2. Build dataset with customized options

To build datasets by customizing options, you can make your own configuration
file (`.yml`) and select target compiler options. You can check the format in
the existing sample files in the `/config` directory. Here, please make sure
that the name of your config file is not included in the blacklist in the
[compilation
script](/SoftSec-KAIST/BinKit/blob/master/do_compile_utils.sh#L347).


# Issues

### Tested environment
We ran all our experiments on a server equipped with four Intel Xeon E7-8867v4
2.40 GHz CPUs (total 144 cores), 896 GB DDR4 RAM, and 4 TB SSD. We setup Ubuntu
16.04 on the server.

### Tested python version
- Python 3.8.0

### Running example

The time spent for running the below script took `7` hours on our machine.

```bash
$ python gnu_compile_script.py \
    --base_dir "/home/dongkwan/binkit/dataset/gnu" \
    --num_jobs 72 \
    --config "config/normal.yml" \
    --whitelist "config/whitelist.txt"
```

### Compliation failure

If compilation fails, you may have to adjust the number of jobs for parallel
processing in the step 1, which is machine-dependent.


# Authors
This project has been conducted by the below authors at KAIST.
* [Dongkwan Kim](https://0xdkay.me/)
* [Eunsoo Kim](https://hahah.kim)
* [Sang Kil Cha](https://softsec.kaist.ac.kr/~sangkilc/)
* [Sooel Son](https://sites.google.com/site/ssonkaist/home)
* [Yongdae Kim](https://syssec.kaist.ac.kr/~yongdaek/)

# Citation
We would appreciate if you consider citing [our
paper](https://ieeexplore.ieee.org/document/9813408) when using BinKit.
```bibtex
@ARTICLE{kim:tse:2022,
  author={Kim, Dongkwan and Kim, Eunsoo and Cha, Sang Kil and Son, Sooel and Kim, Yongdae},
  journal={IEEE Transactions on Software Engineering}, 
  title={Revisiting Binary Code Similarity Analysis using Interpretable Feature Engineering and Lessons Learned}, 
  year={2022},
  volume={},
  number={},
  pages={1-23},
  doi={10.1109/TSE.2022.3187689}
}
```
