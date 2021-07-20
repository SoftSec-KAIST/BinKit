import os, re, glob, sys
import requests
import time
import itertools
import yaml
import pprint as pp

from bs4 import BeautifulSoup

from compile_checker import check_package
from utils import gettmpdir, get_dirs

import logging, coloredlogs

coloredlogs.install(level=logging.INFO)
logger = logging.getLogger(__name__)

# Below packages are blacklisted.
BLACKLIST = [
    # produce too many threads, so process will burn!
    "kawa",
    "classpath",
    "gettext",
    "guile",
    "gnu-crypto",
    # no debugging info left...
    "ncurses",
    # takes too much time to compile,
    "smalltalk",
    "gforth",
    "acm",
    # package dependency
    "bison",
    # something stuck
    "oleo",
    "octave",
    "xaos",
    "swbis",
    "bayonne",
    "cssc",
    # do not need to try. there is no binary
    "teximpatient",
    "websocket4j",
]


def extract_packages(packages, num_jobs=8):
    t0 = time.time()
    cmds = []
    for package in packages:
        cmd = " ".join(
            [
                "bash",
                "do_extract.sh",
                package["orig_name"],
                package["tar_name"],
                package["work_dir"],
            ]
        )
        cmds.append(cmd)

    # using command line parallel is much faster than pytho multiprocessing.
    fname = os.path.join(gettmpdir(), "gnu_compile_script_cmds.txt")
    with open(fname, "w") as f:
        f.write("\n".join(cmds) + "\n")

    if len(cmds) < num_jobs:
        num_jobs = len(cmds)

    os.system("parallel -j {0} :::: {1}".format(num_jobs, fname))
    logger.info("done. %0.3fs", time.time() - t0)


def download_file(o_fname, url):
    r = requests.get(url, stream=True)
    with open(o_fname, "wb") as f:
        for chunk in r.iter_content(chunk_size=4096):
            if chunk:
                f.write(chunk)

    return o_fname


def download_packages(src_dir, log_dir, whitelist=[]):
    base_url = "http://ftp.gnu.org/gnu/"
    r = requests.get(base_url)
    dirs = BeautifulSoup(r.text, "lxml").findAll("a")
    dirs = list(filter(lambda x: x.text.endswith("/"), dirs))

    for d in dirs:
        assert d.parent.parent.find("img").attrs["alt"] == "[DIR]"

        package = d.text.rstrip("/")

        if whitelist:
            if all(word not in package for word in whitelist):
                continue

        if any(word in package for word in BLACKLIST):
            continue

        o_dir = os.path.join(src_dir, package)
        if os.path.exists(o_dir):
            continue

        url = base_url + d.attrs["href"]
        page = requests.get(url)
        orig_files = BeautifulSoup(page.text, "lxml").findAll("a")

        files = list(
            filter(
                lambda x: re.search(
                    "{0}[^-]*-[0-9.]+\.(tar.gz|tar.xz|tar.bz2)$".format(
                        re.escape(package)
                    ),
                    x.text,
                    re.IGNORECASE,
                ),
                orig_files,
            )
        )

        if not files:
            os.makedirs(log_dir, exist_ok=True)
            fail_fname = os.path.join(log_dir, "download_fail.txt")
            with open(fail_fname, "a") as f:
                f.write(pp.pformat(package) + "\n")
                f.write(pp.pformat(orig_files) + "\n")
            continue

        # sort by versions
        files.sort(
            key=lambda x: list(
                map(
                    int,
                    re.search("-([0-9\.]+)\.tar", x.text, re.IGNORECASE)
                    .group(1)
                    .split("."),
                )
            )
        )

        # download only the latest one
        target = files[-1]
        down_url = url + target.attrs["href"]
        o_fname = os.path.join(o_dir, target.text)

        t0 = time.time()
        logger.info("download %s at %s", package, o_fname)
        os.makedirs(o_dir, exist_ok=True)
        download_file(o_fname, down_url)
        logger.debug("done ... %0.3fs", time.time() - t0)


def list_packages(src_dir, out_dir, log_dir, whitelist=[]):
    src_dir = os.path.abspath(src_dir)
    files = sorted(glob.glob("{0}/*/*.tar*".format(src_dir)))
    packages = list(
        map(
            lambda x: {
                "path": x,
                "name": os.path.basename(os.path.dirname(x)),
                "version": re.search("-([0-9\.]+)\.tar", x).group(1),
            },
            files,
        )
    )

    if whitelist:
        packages = list(filter(lambda x: x["name"] in whitelist, packages))

    packages = list(
        map(
            lambda package: {
                "orig_name": package["name"],
                "tar_name": os.path.basename(package["path"]),
                "version": package["version"],
                "work_dir": os.path.dirname(package["path"]),
                "out_dir": os.path.join(out_dir, package["name"]),
                "log_dir": os.path.join(log_dir, package["name"]),
                "name": "-".join([package["name"], package["version"]]),
            },
            packages,
        )
    )

    packages = list(
        filter(
            lambda x: all(word not in x["orig_name"] for word in BLACKLIST), packages
        )
    )

    return packages


def compile_package(
    packages,
    to_compile,
    opti_list,
    arch_list,
    compiler_list,
    suffix,
    echo=False,
    num_jobs=8,
):
    t0 = time.time()
    cmds = []
    logger.info("[+] start compiling %d packages ...", len(to_compile))
    for package in packages:
        package_name = package["name"]
        if package_name not in to_compile or len(to_compile[package_name]) == 0:
            # no need to compile this package since it is already checked!
            continue

        opts = to_compile[package_name]
        logger.debug("%s: %d options left", package_name, len(opts))

        for opt in opts:
            compiler, arch, opti = opt.split(":")
            if (
                compiler not in compiler_list
                or arch not in arch_list
                or opti not in opti_list
            ):
                continue

            cmd = " ".join(
                [
                    "timeout",
                    str(60 * 30),
                    "bash",
                    "do_compile_utils.sh",
                    package["orig_name"],
                    package["tar_name"],
                    package["version"],
                    package["work_dir"],
                    package["out_dir"],
                    package["log_dir"],
                    opti,
                    arch,
                    compiler,
                    suffix,
                    str(echo),
                ]
            )
            cmds.append(cmd)
            print(cmd)

    # using command line parallel is much faster than pytho multiprocessing.
    fname = os.path.join(gettmpdir(), "gnu_compile_script_cmds.txt")
    with open(fname, "w") as f:
        f.write("\n".join(cmds) + "\n")

    if len(cmds) < num_jobs:
        num_jobs = len(cmds)

    os.system("parallel -j {0} :::: {1}".format(num_jobs, fname))
    logger.info("done. %0.3fs", time.time() - t0)


if __name__ == "__main__":
    from multiprocessing import cpu_count
    from optparse import OptionParser

    op = OptionParser()
    op.add_option(
        "--download",
        action="store_true",
        dest="download",
        default=False,
        help="Download gnu packages",
    )
    op.add_option(
        "--config",
        action="store",
        dest="config",
        help="give config file (ex) config/compile_options.yml",
    )
    op.add_option(
        "--debug",
        action="store_true",
        dest="debug",
        default=True,
        help="Add -g when compiling",
    )
    op.add_option(
        "--check",
        action="store_true",
        dest="check",
        default=False,
        help="check files only",
    )
    op.add_option(
        "--num_jobs",
        action="store",
        dest="num_jobs",
        type=int,
        default=cpu_count(),
        help="number of processors simultaneously compile",
    )
    op.add_option(
        "--whitelist",
        action="store",
        dest="whitelist",
        type=str,
        default="",
        help="whitelist file to filter",
    )
    op.add_option(
        "--base_dir",
        action="store",
        dest="base_dir",
        type=str,
        help="base diretory of all outputs",
    )
    op.add_option(
        "--echo",
        action="store_true",
        dest="echo",
        default=False,
        help="turn on debug echo",
    )
    (opts, args) = op.parse_args()

    if not opts.base_dir:
        logger.error("You must give base directory")
        exit(1)

    # =====================================
    # load whitelist
    # =====================================
    if opts.whitelist:
        if not os.path.exists(opts.whitelist):
            logger.error("No such file: %s", opts.whitelist)

        logger.info("Loading whitelist: %s", opts.whitelist)
        with open(opts.whitelist, "r") as f:
            whitelist = f.readlines()
        whitelist = list(filter(lambda x: not x.startswith("#"), whitelist))
        whitelist = list(
            map(
                lambda x: re.sub("(_debug|_noinline|_lto|_pie|_normal)", "", x.strip()),
                whitelist,
            )
        )
        logger.info("%d packages in the whitelist", len(whitelist))

    else:
        whitelist = []

    # =====================================
    # download packages from gnu ftp
    # =====================================
    if opts.download:
        base_dir = opts.base_dir
        src_dir, out_dir, log_dir = get_dirs(base_dir)
        os.makedirs(src_dir, exist_ok=True)
        os.makedirs(log_dir, exist_ok=True)
        logger.info("base directory   : %s", base_dir)
        logger.info("source directory : %s", src_dir)
        logger.info("log directory    : %s", log_dir)

        download_packages(src_dir, log_dir, whitelist)
        packages = list_packages(src_dir, out_dir, log_dir, whitelist)
        extract_packages(packages, num_jobs=opts.num_jobs)
        exit(0)

    # =====================================
    # compile downloaded gnu_packages
    # =====================================
    if not opts.config or not os.path.exists(opts.config):
        logger.error("no such config file: %s", opts.config)
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

    # abs_dir = os.path.dirname(os.path.abspath(__file__))
    with open(opts.config, "r") as f:
        config = yaml.safe_load(f)

    opti_list = config["opti"]
    arch_list = config["arch"]
    compiler_list = config["compiler"]
    num_opt = len(opti_list) * len(arch_list) * len(compiler_list)
    logger.info("Total %d options!", num_opt)

    packages = list_packages(src_dir, out_dir, log_dir, whitelist)
    if not packages:
        logger.error("Please download packages first.")
        exit(1)

    t0 = time.time()
    if not opts.check:
        # check already compiled packages
        to_compile = check_package(packages, config)

        num_jobs = int(opts.num_jobs)
        logger.info("Multiprocessing: %d jobs", opts.num_jobs)

        # start compile
        compile_package(
            packages,
            to_compile,
            opti_list,
            arch_list,
            compiler_list,
            suffix,
            opts.echo,
            num_jobs=num_jobs,
        )

    to_compile = check_package(packages, config)

    logger.info("done. %0.3fs", time.time() - t0)
