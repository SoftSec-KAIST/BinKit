import os, re, glob, sys
import time
import pprint as pp
import itertools
import yaml

from collections import defaultdict

from utils import system, get_file_type, RESTR, gettmpdir, get_dirs

import logging, coloredlogs

coloredlogs.install(level=logging.INFO)
logger = logging.getLogger(__name__)


def check_package(packages, config):
    logger.info("Checking %d packs if already compiled ...", len(packages))
    t0 = time.time()
    opti_list = config["opti"]
    arch_list = config["arch"]
    compiler_list = config["compiler"]

    to_compile = {}
    success_list = {}
    fail_list = {}
    for package in packages:
        res = check_dir(package["out_dir"], config)

        if not res or (not res[0] and not res[1] and not res[2]):
            # no binary exists. need to compile all
            opts = [compiler_list, arch_list, opti_list]
            opts = list(itertools.product(*opts))
            opts = set(map(lambda x: ":".join(x), opts))
            to_compile[package["name"]] = opts
            continue

        succ, fail, arch_fail = res
        if succ and package["name"] in succ:
            # there may exist other packages. we only filter target packages
            success_list[package["name"]] = succ[package["name"]]

        if fail and package["name"] in fail:
            fail_list[package["name"]] = fail[package["name"]]

            # Compile only if none of the binaries is compiled. If any binary
            # exists, this package is already compiled! It is higly likely that
            # the left binaries will be not compiled again.
            if not succ:
                # merge all failed binaries.
                to_compile[package["name"]] = set()
                for bin_name, opts in fail[package["name"]]:
                    to_compile[package["name"]].update(opts)

    logger.info(
        "%d packs, %d bins success.",
        len(success_list),
        sum(map(len, success_list.values())),
    )
    logger.info(
        "%d packs, %d bins failed. (%0.3fs).",
        len(fail_list),
        sum(map(len, fail_list.values())),
        time.time() - t0,
    )
    logger.info(
        "%d packs should be compiled. (%0.3fs).", len(to_compile), time.time() - t0
    )

    return to_compile


def check_dir(path, config, check_arch=False, show_opti=True):
    opti_list = config["opti"]
    arch_list = config["arch"]
    compiler_list = config["compiler"]

    # - architecture check is done in the compile script
    # - show_opti removes opti levels to reduce the number of options to show
    if not opti_list or not arch_list or not compiler_list:
        logger.error("you should give at list one option.")
        return

    if not os.path.exists(path):
        return

    cmd = "find {0} -type f -executable | sort".format(path)
    if check_arch:
        cmd += " | xargs file"
    files = system(cmd).splitlines()
    if not files:
        return

    check_list = defaultdict(lambda: defaultdict(set))
    arch_fail_list = defaultdict(lambda: defaultdict(list))
    success_list = defaultdict(list)
    fail_list = defaultdict(list)

    for b in files:
        if check_arch:
            b, b_type = b.split(":")

        base_name = os.path.basename(b)
        matches = re.search(RESTR, base_name).groups()
        package, compiler, arch, opti, bin_name = matches
        bin_name = bin_name.replace(".elf", "")

        if opti not in opti_list:
            continue
        if arch not in arch_list:
            continue
        if compiler not in compiler_list:
            continue

        check_list[package][bin_name].add(":".join([compiler, arch, opti]))

        if check_arch:
            # we use the command line result since it is much faster
            real_arch = get_file_type(b_type, use_str=True)
            if real_arch != arch:
                arch_fail_list[package][bin_name].append((b, arch, real_arch))

    opts = [compiler_list, arch_list, opti_list]
    opts = list(itertools.product(*opts))
    opts = set(map(lambda x: ":".join(x), opts))
    num_opt = len(opts)

    for package, val in check_list.items():
        for bin_name, opt in val.items():
            left_options = opts - set(opt)
            if not left_options:
                success_list[package].append((bin_name, opt))
            else:
                if not show_opti:
                    left_options = set(
                        map(lambda x: re.sub(":O(0|1|2|3|s)", "", x), left_options)
                    )
                fail_list[package].append((bin_name, left_options))

    return success_list, fail_list, arch_fail_list


def check_archs(out_dir, config):
    opti_list = config["opti"]
    arch_list = config["arch"]
    compiler_list = config["compiler"]
    remove_list = []

    _, _, arch_fail_list = check_dir(out_dir, config, check_arch=True)

    for package, val in arch_fail_list.items():
        for bin_name, (path, arch, real_arch) in val.items():
            remove_list.append(path)

    return remove_list


def remove_files(remove_list):
    if not remove_list:
        return

    logger.warning("removing unnecessary files ...")
    fname = os.path.join(gettmpdir(), "gnu_compile_remove_list.txt")
    with open(fname, "w") as f:
        for r in remove_list:
            f.write(r + "\n")
    logger.warning("%d files and directories have been removed.", len(remove_list))

    # command line program is much faster.
    os.system("cat {0} | xargs rm -rf".format(fname))


def check_hash(path, opti, arch, comp):
    cmd = "find {0} -type f -executable".format(path)
    cmd += ' -name "*{0}_{1}_{2}*" '.format(comp, arch, opti)
    cmd += "| sort | xargs md5sum"
    lines = system(cmd).splitlines()
    hashes = defaultdict(list)
    for line in lines:
        h, f = line.split()
        hashes[h].append(f)

    return hashes


def check_duplicates(out_dir, config):
    opti_list = config["opti"]
    arch_list = config["arch"]
    compiler_list = config["compiler"]

    # checking hash values for one option is enough. If we find one, we removes
    # the binary in all other options.
    hashes = check_hash(out_dir, opti_list[0], arch_list[0], compiler_list[0])
    duplicates = list(filter(lambda x: len(x) > 1, hashes.values()))
    remove_list = []

    for bins in duplicates:
        # only leave shortest name binaries among the duplicates
        bins = sorted(
            bins, key=lambda x: len(re.search(RESTR, os.path.basename(x)).groups()[-1])
        )
        for b in bins[1:]:
            base_name = os.path.basename(b)
            dir_name = os.path.dirname(b)
            matches = re.search(RESTR, base_name).groups()
            package, compiler, arch, opti, bin_name = matches

            option_lists = [opti_list, arch_list, compiler_list]
            options = list(itertools.product(*option_lists))
            for opti, arch, comp in options:
                name = "_".join([package, comp, arch, opti, bin_name])
                name = os.path.join(dir_name, name)
                remove_list.append(name)

    return remove_list


# return binaries without the PIE option
def check_pie(path, lib_ok=True, num_jobs=1):
    cmd = "find {0} -type f -executable | sort".format(path)
    bins = system(cmd).splitlines()

    if lib_ok:
        # leave .so files
        bins = list(filter(lambda x: ".so" not in x, bins))

    # check if PIE is applied
    cmds = list(
        map(
            lambda x: 'if [ -z "$(readelf -h {0} | grep DYN)" ];'
            ' then echo "{0}"; fi'.format(x),
            bins,
        )
    )

    if len(cmds) < num_jobs:
        num_jobs = len(cmds)

    # TODO: make fname to tmpfile
    cmd_fname = "/tmp/piecheck_cmds.txt"
    with open(cmd_fname, "w") as f:
        f.write("\n".join(cmds) + "\n")

    results = system("parallel -j {0} :::: {1}".format(num_jobs, cmd_fname))
    results = results.splitlines()

    return results


if __name__ == "__main__":
    from optparse import OptionParser
    from multiprocessing import cpu_count

    op = OptionParser()
    op.add_option(
        "--config",
        action="store",
        dest="config",
        help="give config file (ex) config/compile_options.yml",
    )
    op.add_option(
        "--remove",
        action="store_true",
        dest="remove",
        default=False,
        help="remove unnecessary package, binaries",
    )
    op.add_option(
        "--check_arch",
        action="store_true",
        dest="check_arch",
        default=False,
        help="check architecture",
    )
    op.add_option(
        "--base_dir",
        action="store",
        dest="base_dir",
        type=str,
        help="base diretory of all outputs",
    )
    op.add_option(
        "--num_jobs",
        action="store",
        dest="num_jobs",
        type=int,
        default=cpu_count(),
        help="number of processors simultaneously compile",
    )
    (opts, args) = op.parse_args()

    if not opts.base_dir:
        logger.error("You must give base directory")
        op.print_help()
        exit()

    if not opts.config or not os.path.exists(opts.config):
        logger.error("No such config file: %s", opts.config)
        op.print_help()
        exit()

    # make the filename as suffix of compiled binaries
    suffix = "_" + os.path.splitext(os.path.basename(opts.config))[0]
    base_dir = opts.base_dir
    src_dir, out_dir, log_dir = get_dirs(opts.base_dir, suffix)
    os.makedirs(src_dir, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(log_dir, exist_ok=True)
    logger.info("base directory   : %s", base_dir)
    logger.info("source directory : %s", src_dir)
    logger.info("output directory : %s", out_dir)
    logger.info("log directory    : %s", log_dir)

    with open(opts.config, "r") as f:
        config = yaml.safe_load(f)

    opti_list = config["opti"]
    arch_list = config["arch"]
    compiler_list = config["compiler"]
    num_opt = len(opti_list) * len(arch_list) * len(compiler_list)
    logger.info("[+] Compile checker! checking %d options", num_opt)
    start_time = time.time()

    # =================================
    if opts.check_arch:
        t0 = time.time()
        logger.info("check architecture ...")
        remove_list = check_archs(out_dir, config)
        if remove_list:
            logger.info("%d do not match. (%0.4fs)", len(remove_list), time.time() - t0)
            if opts.remove:
                remove_files(remove_list)

    # =================================
    t0 = time.time()
    logger.info("checking duplicates ...")
    remove_list = check_duplicates(out_dir, config)
    if remove_list:
        logger.info("%d duplicates exist. (%0.4fs)", len(remove_list), time.time() - t0)
        if opts.remove:
            remove_files(remove_list)

    # =================================
    # currently no pie violation exists
    if "pie" in suffix:
        t0 = time.time()
        logger.info("checking pie violation ...")
        remove_list = check_pie(out_dir, lib_ok=True, num_jobs=opts.num_jobs)
        if remove_list:
            logger.info(
                "%d files violate pie. (%0.4fs)", len(remove_list), time.time() - t0
            )
            if opts.remove:
                remove_files(remove_list)

    logger.info("all checking procedures are done. (%0.4fs)", time.time() - start_time)
