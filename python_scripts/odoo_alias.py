#!/usr/bin/env python3
import sys
import os
import collections
import subprocess
from textwrap import dedent as _dd
from psycopg2 import OperationalError, ProgrammingError, connect

from utils import env
from git_odoo import _repos, _get_version_from_db, App as _git_odoo_app


########################
#   decorators stuff   #
########################

CALLABLE_FROM_SHELL = set()
SHELL_END_HOOK = set()
SHELL_DIFFERED_COMMANDS_FILE = f"{env.AP}/differed_commands.txt"
differed_sh_run_new_batch = True


def call_from_shell(func):
    # decorator for functions that are meant to be called directly from the shell
    CALLABLE_FROM_SHELL.add(func.__name__)
    return func


def shell_end_hook(func):
    # decorator for functions that need to call a shell
    # command AFTER the python script exits
    # the decorated app should call `differed_sh_run`
    SHELL_END_HOOK.add(func.__name__)
    return func


def differed_sh_run(cmd):
    # prepare a command to be executed after the end of the python script
    # can only work in functions decorated with `shell_end_hook`
    # or called by functions decorated with `shell_end_hook`
    global differed_sh_run_new_batch
    write_mode = "w" if differed_sh_run_new_batch else "a"
    with open(SHELL_DIFFERED_COMMANDS_FILE, write_mode) as f:
        f.write(cmd + "\n")
    differed_sh_run_new_batch = False


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
def git_branch_version(path):
    print(_get_branch_name(path))


def _check_file_exists(path):
    # returns True if the file :path exists, False otherwize
    try:
        with open(path) as f:
            return True
    except IOError:
        return False


def sh_run(cmd, **kwargs):
    # wrapper for subprocess.run
    if "stdout" not in kwargs.keys():
        kwargs["stdout"] = subprocess.PIPE
    if "|" not in cmd:
        cmd = cmd.split()
        return subprocess.run(cmd, **kwargs).stdout.decode("utf-8")
    else:
        process = subprocess.Popen(cmd, shell=True, **kwargs)
        return process.communicate()[0].decode("utf-8")


@call_from_shell
def clear_pyc(*args):
    # remove compiled python files from the main source folder
    sh_run(f"find {env.SRC} -type d -name __pycache__ | xargs rm -rf")
    sh_run(f"find {env.SRC} -name '*.pyc' -delete")
    if args and args[0] == "--all":
        sh_run(f"find {env.SRC_MULTI} -type d -name __pycache__ | xargs rm -rf")
        sh_run(f"find {env.SRC_MULTI} -name '*.pyc' -delete")


def psql(dbname, query):
    # execute an sql query on a given database
    with connect(f"dbname='{dbname}'") as conn, conn.cursor() as cr:
        cr.execute(query)
        try:
            return cr.fetchall()
        except ProgrammingError:
            # printing a tactical dot to know that we went through here at least
            print(".")
            return []


#####################################################################################
#                      Put "main" functions bellow this bloc                        #
#  The params of functions callable from the shell are positional, and string only  #
#####################################################################################


def _so_checker(*args):
    # check that the params given to 'so' are correct,
    # check that I am not trying to start a protected DB,
    # check that I am sure to want to start a DB with the wrong branch checked out (only check $ODOO)

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
    except OperationalError:
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


@call_from_shell
def _so_builder(db_name, port_number=8069, *args):
    ODOO_BIN_PATH = f"{env.ODOO}/odoo-bin"
    ODOO_PY_PATH = f"{env.ODOO}/odoo.py"
    PATH_COMMUNITY = f"--addons-path={env.ODOO}/addons"
    PATH_ENTERPRISE = (
        f"--addons-path={env.ENTERPRISE},{env.ODOO}/addons,{env.SRC}/design-themes"
    )
    PARAMS_NORMAL = f"--db-filter=^{db_name}$ -d {db_name} --xmlrpc-port={port_number}"
    additional_params = " ".join(args)
    if _check_file_exists(ODOO_BIN_PATH):
        # version 10 or above
        cmd = f"{ODOO_BIN_PATH} {PATH_ENTERPRISE} {PARAMS_NORMAL} {additional_params}"
    else:
        # version 9 or below
        try:
            version = _get_version_from_db(db_name)
        except OperationalError as e:
            msg = f"""{e}
                Note:
                `so` does not work with DBs < 10.0, unless it already exists
                This will probably never be fixed."""
            raise Invalid_params(msg)
        if version == "8.0":
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
    out = sh_run(cmd)
    # this is to make `so --help` work
    print(out)


def _soiu(mode, db_name, *apps):
    assert mode in ("install", "upgrade")
    mode = "-i" if mode == "install" else "-u"
    assert apps, "No apps list provided"
    apps = ",".join(apps)
    so(db_name, 1234, mode, apps, "--stop-after-init")


@call_from_shell
def soi(db_name, *apps):
    # install modules args[1:] on DB args[0]
    _soiu("install", db_name, *apps)


@call_from_shell
def sou(db_name, *apps):
    # upgrade modules args[1:] on DB args[0]
    _soiu("upgrade", db_name, *apps)


# start python scripts with the vscode python debugger
# note that the debbuger is on the called script,
# if that script calls another one, that one is not "debugged"
# so it doesn't work with oe-support.
# doesn't work with alias calling python scripts
@call_from_shell
def ptvsd2(*args):
    cmd = "python2 -m ptvsd --host localhost --port 5678".split() + list(args)
    subprocess.run(cmd)


@call_from_shell
def ptvsd3(*args):
    cmd = "python3 -m ptvsd --host localhost --port 5678".split() + list(args)
    subprocess.run(cmd)


def _ptvsd_so(python_version, *args):
    args = list(args) + ["--limit-time-real=1000", "--limit-time-cpu=600"]
    _so_checker(*args)
    cmd = _so_builder(*args)
    cmd = cmd.split()
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


@shell_end_hook
@call_from_shell
def go(*args):
    # switch branch for all odoo repos
    print("cleaning all the junk")
    clear_pyc()
    params = {"checkout": True, "<version>": args}
    _git_odoo_app(**params)
    if len(args) == 1:
        differed_sh_run(f"go_venv {args[0]}")
    print("-----------")
    differed_sh_run("golist")


@shell_end_hook
@call_from_shell
def go_update_and_clean(version=None):
    # git pull on all the repos of the main source folder (except for support-tools)
    params = {"pull": True, "--version": version}
    _git_odoo_app(**params)
    clear_pyc()
    differed_sh_run("go_venv_current")
    differed_sh_run("echo '--------'")
    differed_sh_run("golist")


@shell_end_hook
@call_from_shell
def godb(db_name):
    # switch repos branch to the version of the given DB
    try:
        version = _get_version_from_db(db_name)
    except OperationalError:
        print(f"DB {db_name} does not exist")
    else:
        params = {"checkout": True, "--dbname": db_name}
        _git_odoo_app(**params)
        differed_sh_run(f"go_venv {version}")


@shell_end_hook
@call_from_shell
def goso(db_name, *args):
    # switch repos to the version of given db and starts it
    godb(db_name)
    so(db_name, *args)


@shell_end_hook
@call_from_shell
def dropodoo(*dbs):
    """drop the given DBs and remove its filestore,
    also removes it from meta if it was a local saas db"""
    import appdirs
    from shutil import rmtree

    if not dbs:
        raise Invalid_params(
            """\
            Requires the name(s) of the DB(s) to drop
            dropodoo <db_name(s)>"""
        )
    protection_file = f"{env.AP}/drop_protected_dbs.txt"
    with open(protection_file, "r") as f:
        drop_protected_dbs = [db.strip() for db in f]
    for db in dbs:
        if db in drop_protected_dbs:
            raise Invalid_params(
                f"""\
                DB {db} is drop protected --> aborting
                To override protection, modify the protection file at {protection_file}"""
            )
        # remove from meta
        psql("meta", f"DELETE FROM databases WHERE name = '{db}'")
        # dropping
        if db.startswith("oe_support_"):
            print(f"Dropping the DB {db} using oe-support")
            differed_sh_run(f"oes cleanup {db[11:]}")
        else:
            psql(
                "postgres",
                f"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '{db}'",
            )
            sh_run(f"dropdb {db}")
            FS_DIR = os.path.join(appdirs.user_data_dir("Odoo"), "filestore")
            filestore_path = os.path.expanduser(os.path.join(FS_DIR, db))
            rmtree(filestore_path)


@call_from_shell
def go_fetch(*args):
    # git fetch on all the repos of the main source folder
    _git_odoo_app(fetch=True)


#  vvvvvv   not strictly odoo   vvvvvvv


@call_from_shell
def shurl(long_url):
    """Returns (and prints) a short (and tracked) url version of a link.
    Hosted on an odoo saas server"""
    import xmlrpc.client
    from functools import partial

    api_key = env.SHORT_URL_KEY
    api_login = env.SHORT_URL_LOGIN
    assert all((api_key, api_login))
    dburl = "https://short-url.moens.xyz"
    db = "noapp"
    # connect to https://short-url.moens.xyz/ create a link.tracker with args[0] as the url field
    # the get short_url field from the newly created record
    common = xmlrpc.client.ServerProxy("{}/xmlrpc/2/common".format(dburl))
    models = xmlrpc.client.ServerProxy("{}/xmlrpc/2/object".format(dburl))
    uid = common.authenticate(db, api_login, api_key, {})
    r_exec = partial(models.execute_kw, db, uid, api_key)
    data = {"url": long_url}
    url_id = r_exec("link.tracker", "create", [data])
    short_url = r_exec(
        "link.tracker",
        "search_read",
        [[["id", "=", url_id]]],
        {"fields": ["short_url"]},
    )[0]["short_url"]
    print(short_url)
    return short_url


@call_from_shell
def compare_our_modules(old_json_file, new_json_file):
    """ Print a list of the newly added modules. """
    import json
    from collections import defaultdict

    with open(old_json_file) as f_old, open(new_json_file) as f_new:
        old_data = json.load(f_old)
        new_data = json.load(f_new)
    # extract only the newly added modules
    only_new = defaultdict(list)
    for version, modules in new_data.items():
        for module in modules:
            if module not in old_data[version]:
                only_new[version].append(module)
    # inverse mapping for easier formating
    only_new_by_module = defaultdict(list)
    for version, modules in only_new.items():
        for module in modules:
            only_new_by_module[module].append(version)

    print("[IMP] clean_database: update `our modules` list")
    print("")
    print("New module(s):")
    for module, versions in only_new_by_module.items():
        versions.sort()
        pretty_versions = f"({', '.join(versions)})"
        print(f"{module} {pretty_versions}")


@shell_end_hook
@call_from_shell
def our_modules_update_and_compare(*args):
    dry_run = True
    args = list(args)
    if "--pull-request" in args:
        dry_run = False
        args.remove("--pull-request")
    params = " ".join(args) if args else "--update-branches"
    if dry_run:
        print(
            """
            ------------------------------------------------------
            This will not create a pull request
            Add the `--pull-request` option to create the branch,
            commit and pull request.
            ------------------------------------------------------
            """
        )
    cmds = f"""cd $ST/scripts/clean_database_helper/
    git switch master
    git pull
    cp OUR_MODULES.json /tmp/OUR_MODULES_OLD.json
    ./Our_modules_generator.py {params}
    cp OUR_MODULES.json /tmp/OUR_MODULES_NEW.json
    """
    if dry_run:
        cmds += """compare_our_modules /tmp/OUR_MODULES_OLD.json /tmp/OUR_MODULES_NEW.json
        git stash
        """
    else:
        cmds += """git add OUR_MODULES.json
        git checkout -b "master-ourmodulesupdate$(date -u +'%Y%m%d')-mao"
        compare_our_modules /tmp/OUR_MODULES_OLD.json /tmp/OUR_MODULES_NEW.json | git commit -F -
        test -z "$(git diff HEAD master)" || ( git push --set-upstream  origin  "master-ourmodulesupdate$(date -u +'%Y%m%d')-mao" && gh pr create --title "[IMP] clean_database: update `our modules` list" --body " ")
        git switch master
        git branch -D "master-ourmodulesupdate$(date -u +'%Y%m%d')-mao"
        """
    differed_sh_run(cmds)


@shell_end_hook
@call_from_shell
def dummy_command(*args):
    print("in python")
    differed_sh_run("echo 'in shell'")


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
