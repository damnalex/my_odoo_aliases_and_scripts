#!/usr/bin/env python3
import sys
import os
import psycopg2
from collections import namedtuple
import subprocess

from git_odoo import _repos, _get_version_from_db

# environment variables
env = [
    "AP",
    "SRC",
    "ODOO",
    "ENTERPRISE",
    "INTERNAL",
    "ST",
    "SRC_MULTI",
    "ODOO_STORAGE",
]
env = {e: os.getenv(e) for e in env}
EnvTuple = namedtuple("Env", " ".join(env.keys()))
env = EnvTuple(**env)
# env.XXX now stores the environment variable XXX

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


def _check_file_exists(path):
    # returns True if the file :path exists, False otherwize
    try:
        with open(path) as f:
            return True
    except IOError:
        return False


def _dd(multiline_string):
    # wrapper for textwrap.dedent
    from textwrap import dedent

    return dedent(multiline_string)


########################################################################
#                Put "main" functions bellow this bloc                 #
#  The params of the public functions are positional, and string only  #
########################################################################


def _so_checker(*args):
    # check that the params given to 'so' are correct,
    # check that I am not trying to start a protected DB,
    # check that I am sure to want to start a DB with the wrong branch checked out (only check $ODOO)
    if len(args) == 0:
        raise Invalid_params(
            _dd(
                """At least give me a name :(
                so dbname [port] [other_parameters]
                note: port is mandatory if you want to add other parameters"""
            )
        )
    db_name = args[0]
    if db_name.startswith("CLEAN_ODOO"):
        raise Invalid_params(
            _dd(
                f"""Don't play with that one!
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
                    f"""Version mismatch
                    DB version is: {db_version}
                    repo version is: {checked_out_branch}"""
                )
            )
            ans = input("continue anyway? (y/N):").lower()
            if ans == "y":
                print("I hope you know what you're doing...")
            else:
                raise UserAbort("Yeah, that's probably safer :D")


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


def so(*args):
    # start an odoo db
    if len(args) and args[0] == "--help":
        so("fakeDBname", 678, "--help")
        # fakeDBname & 678 don't mean anything here
    _so_checker(*args)
    cmd = _so_builder(*args)
    cmd = [word for word in cmd.split(" ") if word]
    subprocess.run(cmd)


def _soiu(dbname, mode, *apps):
    assert mode in ("install", "upgrade")
    mode = "-i" if mode == "install" else "-u"
    if isinstance(apps, str):
        # only 1 app to upgrade/install
        apps = [apps]
    apps = ",".join(apps)
    so(dbname, 1234, mode, apps, "--stop-after-init")


def soi(*args):
    # install modules args[1:] on DB args[0]
    assert len(args) >= 2
    dbname = args[0]
    apps = args[1:]
    _soiu(dbname, "install", *apps)


def sou(*args):
    # upgrade modules args[1:] on DB args[0]
    assert len(args) >= 2
    dbname = args[0]
    apps = args[1:]
    _soiu(dbname, "upgrade", *apps)


# ^^^^^^^^^^^ aliasable functions above this line ^^^^^^^^^

if __name__ == "__main__":
    if len(sys.argv) > 1:
        method_name = sys.argv[1]
        method_params = sys.argv[2:]
        method_params = ", ".join(f"'{param}'" for param in method_params)
        eval(f"{method_name}({method_params})")
    else:
        print("Missing arguments, require at least the function name")
