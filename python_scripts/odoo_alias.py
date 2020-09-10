#!/usr/bin/env python3
import sys
import os
import collections
import subprocess
from textwrap import dedent as _dd

from utils import env
from git_odoo import _repos, _get_version_from_db, App as _git_odoo_app


CALLABLE_FROM_SHELL = set()


def call_from_shell(func):
    # decorator for functions that are meant to be called directly from the shell
    CALLABLE_FROM_SHELL.add(func.__name__)
    return func


#####################################
#   Custom classes and exceptions   #
#####################################


class Invalid_params(Exception):
    pass


class UserAbort(Exception):
    pass


##########################
#    Helper functions    #
##########################


def _get_branch_name(path):
    # return the name of the current branch of repo :path
    # _repos expects multiple path entries in an itterable
    # giving one in a list
    repo_generator = _repos([path])
    repo = list(repo_generator)[0]
    return repo.active_branch.name


@call_from_shell
def git_branch_version(*args):
    (path,) = args
    print(_get_branch_name(path))


def _check_file_exists(path):
    # returns True if the file :path exists, False otherwize
    try:
        with open(path) as f:
            return True
    except IOError:
        return False


def _cmd_string_to_list(cmd):
    # input: a shell command in string form
    # returns the command in a list usable by subprocess.run
    return [word for word in cmd.split()]


def sh_run(cmd, **kwargs):
    # wrapper for subprocess.run
    cmd = _cmd_string_to_list(cmd)
    return subprocess.run(cmd, **kwargs)


@call_from_shell
def clear_pyc(*args):
    # remove compiled python files from the main source folder
    sh_run(f"find {env.SRC} -name '*.pyc' -delete")
    if args and args[0] == "--all":
        sh_run(f"find {env.SRC_MULTI} -name '*.pyc' -delete")
    # remove the compiled files from support-tools
    sh_run(f"rm -r {env.ST}/__pycache__", stderr=subprocess.DEVNULL)
    sh_run(f"rm -r {env.ST}/tools/__pycache__", stderr=subprocess.DEVNULL)


#####################################################################################
#                      Put "main" functions bellow this bloc                        #
#  The params of functions callable from the shell are positional, and string only  #
#####################################################################################


def _so_checker(*args):
    # check that the params given to 'so' are correct,
    # check that I am not trying to start a protected DB,
    # check that I am sure to want to start a DB with the wrong branch checked out (only check $ODOO)
    import psycopg2

    if len(args) == 0:
        raise Invalid_params(
            _dd(
                """\
                At least give me a name :(
                so dbname [port] [other_parameters]
                note: port is mandatory if you want to add other parameters"""
            )
        )
    db_name = args[0]
    if db_name.startswith("CLEAN_ODOO"):
        raise Invalid_params(
            _dd(
                f"""\
                Don't play with that one!
                {db_name} is a protected database."""
            )
        )
    try:
        db_version = _get_version_from_db(db_name)
    except psycopg2.OperationalError:
        # db doesn't exist.
        pass
    else:
        checked_out_branch = _get_branch_name(env.ODOO)
        if db_version != checked_out_branch:
            print(
                _dd(
                    f"""\
                    Version mismatch
                    DB version is: {db_version}
                    repo version is: {checked_out_branch}"""
                )
            )
            ans = input("continue anyway? (y/N):").lower()
            if ans == "y":
                print("I hope you know what you're doing...")
            else:
                raise UserAbort("Yeah, that's probably safer :D")
    if len(args) >= 2:
        try:
            int(args[1])
        except ValueError as ve:
            bad_port = str(ve).split(":")[1][2:-1]
            raise Invalid_params(
                f"""The port number must be an integer. Provided value : {bad_port}"""
            )


def _so_builder(*args):
    # build the command to start odoo
    db_name = args[0]
    if len(args) < 2:
        cmd = _so_builder(db_name, 8069)
        return cmd
    port_number = args[1]
    ODOO_BIN_PATH = f"{env.ODOO}/odoo-bin"
    ODOO_PY_PATH = f"{env.ODOO}/odoo.py"
    PATH_COMMUNITY = f"--addons-path={env.ODOO}/addons"
    PATH_ENTERPRISE = (
        f"--addons-path={env.ENTERPRISE},{env.ODOO}/addons,{env.SRC}/design-themes"
    )
    PARAMS_NORMAL = f"--db-filter=^{db_name}$ -d {db_name} --xmlrpc-port={port_number}"
    additional_params = " ".join(args[2:])
    if _check_file_exists(ODOO_BIN_PATH):
        # version 10 or above
        cmd = f"{ODOO_BIN_PATH} {PATH_ENTERPRISE} {PARAMS_NORMAL} {additional_params}"
    else:
        # version 9 or below
        if _get_version_from_db(env.ODOO) == "8.0":
            cmd = f"{ODOO_PY_PATH} {PATH_COMMUNITY} {PARAMS_NORMAL} {additional_params}"
        else:
            cmd = (
                f"{ODOO_PY_PATH} {PATH_ENTERPRISE} {PARAMS_NORMAL} {additional_params}"
            )
    print(cmd)
    return cmd


@call_from_shell
def so(*args):
    # start an odoo db
    if len(args) and args[0] == "--help":
        so("fakeDBname", 678, "--help")
        # fakeDBname & 678 don't mean anything here
        return
    _so_checker(*args)
    cmd = _so_builder(*args)
    sh_run(cmd)


def _soiu(mode, *args):
    assert mode in ("install", "upgrade")
    mode = "-i" if mode == "install" else "-u"
    dbname, *apps = args
    assert apps, "No apps list provided"
    apps = ",".join(apps)
    so(dbname, 1234, mode, apps, "--stop-after-init")


@call_from_shell
def soi(*args):
    # install modules args[1:] on DB args[0]
    _soiu("install", *args)


@call_from_shell
def sou(*args):
    # upgrade modules args[1:] on DB args[0]
    _soiu("upgrade", *args)


# start python scripts with the vscode python debugger
# note that the debbuger is on the called script,
# if that script calls another one, that one is not "debugged"
# so it doesn't work with oe-support.
# doesn't work with alias calling python scripts
@call_from_shell
def ptvsd2(*args):
    cmd = ["python2", "-m", "ptvsd", "--host", "localhost", "--port", "5678"] + list(
        args
    )
    subprocess.run(cmd)


@call_from_shell
def ptvsd3(*args):
    cmd = ["python3", "-m", "ptvsd", "--host", "localhost", "--port", "5678"] + list(
        args
    )
    subprocess.run(cmd)


def _ptvsd_so(python_version, *args):
    args = list(args) + ["--limit-time-real=1000", "--limit-time-cpu=600"]
    _so_checker(*args)
    cmd = _so_builder(*args)
    cmd = _cmd_string_to_list(cmd)
    if python_version == 3:
        ptvsd3(*cmd)
    else:
        ptvsd2(*cmd)


@call_from_shell
def ptvsd2_so(*args):
    _ptvsd_so(2, *args)


@call_from_shell
def ptvsd3_so(*args):
    _ptvsd_so(3, *args)


@call_from_shell
def go_fetch(*args):
    # git fetch on all the repos of the main source folder
    _git_odoo_app(fetch=True)


# ^^^^^^^^^^^ aliasable functions above this line ^^^^^^^^^

if __name__ == "__main__":
    if len(sys.argv) > 1:
        method_name = sys.argv[1]
        assert method_name in CALLABLE_FROM_SHELL
        method_params = sys.argv[2:]
        method_params = ", ".join(f"'{param}'" for param in method_params)
        try:
            eval(f"{method_name}({method_params})")
        except (Invalid_params, UserAbort) as nice_e:
            print(nice_e)
    else:
        print("Missing arguments, require at least the function name")
