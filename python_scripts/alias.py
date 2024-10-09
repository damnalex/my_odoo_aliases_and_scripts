#!/usr/bin/env python3
import os
import subprocess
import sys
from collections import namedtuple
from configparser import ConfigParser
from functools import cache
from inspect import signature
from itertools import groupby
from socket import gaierror
from textwrap import dedent as _dd

import paramiko
from git_odoo import App as _git_odoo_app
from git_odoo import _get_version_from_db, _repos
from icecream import ic
from psycopg2 import OperationalError, ProgrammingError, connect
from utils import _get_xmlrpc_executer, _xmlrpc_apps, _xmlrpc_master, _xmlrpc_odoo_com, env

PYTHON3, PYTHON2 = 3, 2

########################
#   decorators stuff   #
########################

IGNORE_GENERIC_HELP = set()
CALLABLE_FROM_SHELL = dict()
SHELL_END_HOOK = set()
SHELL_DIFFERED_COMMANDS_FILE = f"{env.AP}/differed_commands.txt"
differed_sh_run_new_batch = True
SHELL_DIFFERED_COMMANDS_DATABASE = "my_alias_meta"


def call_from_shell(func):
    # decorator for functions that are meant to be called directly from the shell
    CALLABLE_FROM_SHELL[func.__name__] = func
    return func


def shell_end_hook(func):
    # decorator for functions that need to call a shell
    # command AFTER the python script exits
    # the decorated app should call `differed_sh_run`
    # can only work with functions decorated with `call_from_shell`
    SHELL_END_HOOK.add(func.__name__)
    return func


# FIX_ME : if commands using `differed_sh_run` are called concurrently in seperate we get a race condition where one will override the other.
# the second to call `differed_sh_run` overrides the first and the first to call loses the differed run
# possible way to fix: store the differed calls in a postgres db, the table could be : id, command_to_run, name of the calling python command, state
# BETTER ALTERNATIVE (that will also allow concurrent calls of the same python alias): generate uuid in calling shell alias, and pass it to this script
def differed_sh_run(cmd):
    # prepare a command to be executed after the end of the python script
    # can only work in functions decorated with `shell_end_hook` and `call_from_shell`
    # or called by functions decorated with `shell_end_hook` and `call_from_shell`
    check_and_create_differed_commands_database()
    prepare_differed_command(cmd)


def check_and_create_differed_commands_database():
    pass
    # TODO:
    # check that the database SHELL_DIFFERED_COMMANDS_DATABASE exist
    #           --> create it if it doesnt
    #                   --> create the right table(s)
    #    else   --> check that the right table(s) exist(s)
    #                   --> create the right table(s) if it doesn't


def prepare_differed_command(cmd):
    pass
    # TODO:
    # Inspect stack to find the first function decorated with `shell_end_hook` and `call_from_shell`
    # Write in SHELL_DIFFERED_COMMANDS_DATABASE the command to execute, name of the "top function" and state `pending`

    # BETTER ALTERNATIVE (that will also allow concurrent calls of the same python alias): generate uuid in calling shell alias, and pass it to this script

    # TODO : remove bellow
    global differed_sh_run_new_batch
    write_mode = "w" if differed_sh_run_new_batch else "a"
    with open(SHELL_DIFFERED_COMMANDS_FILE, write_mode) as f:
        f.write(cmd + "\n")
    differed_sh_run_new_batch = False


def cancel_pending_commands(func_name):
    pass
    # TODO:
    # set state of differed commands in SHELL_DIFFERED_COMMANDS_DATABASE to `cancelled``

    # BETTER ALTERNATIVE (that will also allow concurrent calls of the same python alias): generate uuid in calling shell alias, and pass it to this script
    # TODO : remove below
    # empty the planned differed actions
    open(SHELL_DIFFERED_COMMANDS_FILE, "w").close()


def differed_code_execution_generator(func_name):
    # TODO : generate shell code that :
    # Read from SHELL_DIFFERED_COMMANDS_DATABASE database rather than file
    # Only the pending commands, associated to the specific python function
    # Then set their state to `done`

    # BETTER ALTERNATIVE (that will also allow concurrent calls of the same python alias): generate uuid in calling shell alias, and pass it to this script

    # TODO : remove below
    differed_execution_code = f"""
        while read l; do
            eval $l;
        done <{SHELL_DIFFERED_COMMANDS_FILE}
        date >> $AP/differed_commands_history.txt
        cat {SHELL_DIFFERED_COMMANDS_FILE} >> $AP/differed_commands_history.txt
        cp /dev/null {SHELL_DIFFERED_COMMANDS_FILE}
    """
    return differed_execution_code


def ignore_help(func):
    # decorated fucntion should not be caught be the generic --help handling
    IGNORE_GENERIC_HELP.add(func.__name__)
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
def git_branch_version(path):
    print(_get_branch_name(path))


def _check_file_exists(path):
    # returns True if the file :path exists, False otherwize
    try:
        with open(path) as _:
            return True
    except IOError:
        return False


def sh_run(cmd, **kwargs):
    # wrapper for subprocess.run
    if "stdout" not in kwargs.keys():
        kwargs["stdout"] = subprocess.PIPE
    if "|" not in cmd:
        cmd = cmd.split()
        return subprocess.run(cmd, **kwargs, check=True).stdout.decode("utf-8")
    else:
        process = subprocess.Popen(cmd, shell=True, **kwargs)
        res = process.communicate()[0]
        match res:
            case str():
                return res
            case bytes():
                return res.decode("utf-8")


def _ssh_executor(server, user="odoo"):
    """returns a function that can be used to execute cli commands on the server :server with the user :user"""
    ssh = paramiko.SSHClient()
    ssh.load_host_keys(os.path.expanduser("~/.ssh/known_hosts"))
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(f"{server}.odoo.com", username=user)
    except Exception:
        print(f"Failed to established an ssh connection against server `{server}` with user `{user}`")
        return False, None
    return True, ssh.exec_command


@call_from_shell
def clear_pyc(*args):
    """remove compiled python files from the main source folder
    --all : also cover the multiverse"""
    sh_run(f"find {env.SRC} -type d -name __pycache__ | xargs rm -rf")
    sh_run(f"find {env.SRC} -name '*.pyc' -delete")
    if "--all" in args:
        sh_run(f"find {env.SRC_MULTI} -type d -name __pycache__ | xargs rm -rf")
        sh_run(f"find {env.SRC_MULTI} -name '*.pyc' -delete")


def psql(dbname, query, ignore_error=False):
    # execute an sql query on a given database
    with connect(f"dbname='{dbname}'") as conn, conn.cursor() as cr:
        cr.execute(query)
        try:
            return cr.fetchall()
        except ProgrammingError:
            if ignore_error:
                # printing a tactical dot to know that we went through here at least
                print(".")
                return []
            else:
                raise


#####################################################################################
#                      Put "main" functions bellow this bloc                        #
#  The params of functions callable from the shell are positional, and string only  #
#####################################################################################


def _so_checker(*args):
    # check that the params given to 'so' are correct,
    # check that I am not trying to start a protected DB,
    # check that I am sure to want to start a DB with the wrong branch checked out (only check $ODOO)
    args_pattern = ["<db_name:string>", "<port:int>"]

    if len(args) == 0:
        raise Invalid_params(
            _dd(
                """\
                At least give me a name :(
                so <dbname> [port] [other_parameters]
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
    if len(args) >= len(args_pattern):
        try:
            int(args[1])
        except ValueError as ve:
            bad_port = str(ve).split(":")[1][2:-1]
            raise Invalid_params(f"""The port number must be an integer. Provided value : {bad_port}""") from None


@call_from_shell
def _so_builder(db_name, port_number=8069, *args):
    ODOO_BIN_PATH = f"{env.ODOO}/odoo-bin"
    ODOO_PY_PATH = f"{env.ODOO}/odoo.py"
    PATH_COMMUNITY = f"--addons-path={env.ODOO}/addons"
    PATH_ENTERPRISE = f"--addons-path={env.ENTERPRISE},{env.ODOO}/addons,{env.SRC}/design-themes"
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
            raise Invalid_params(msg) from e
        if version == "8.0":
            cmd = f"{ODOO_PY_PATH} {PATH_COMMUNITY} {PARAMS_NORMAL} {additional_params}"
        else:
            cmd = f"{ODOO_PY_PATH} {PATH_ENTERPRISE} {PARAMS_NORMAL} {additional_params}"
    print(cmd)
    return cmd


@ignore_help
@call_from_shell
def so(*args):
    """start an odoo db"""
    _so_checker(*args)
    if args[0] == "--help":
        so("fakeDBname", 678, "--help")
        # fakeDBname & 678 don't mean anything here
        return
    cmd = _so_builder(*args)
    try:
        out = sh_run(cmd)
    except KeyboardInterrupt:
        out = "\n\n\n\nServer Stopped by KeyboardInterrupt"
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
    """install some given modules on a given DB

    usage:
        soi <db_name> [<modules>...]"""
    _soiu("install", db_name, *apps)


@call_from_shell
def sou(db_name, *apps):
    """upgrade some given modules on a given DB

    usage:
        sou <db_name> [<modules>...]"""
    _soiu("upgrade", db_name, *apps)


# start python scripts with the vscode python debugger
# note that the debbuger is on the called script,
# if that script calls another one, that one is not "debugged"
# so it doesn't work with oe-support.
# doesn't work with alias calling python scripts
@call_from_shell
def ptvsd2(*args):
    cmd = "python2 -m ptvsd --host localhost --port 5678".split() + list(args)
    subprocess.run(cmd, check=True)


@call_from_shell
def ptvsd3(*args):
    cmd = "python3 -m ptvsd --host localhost --port 5678".split() + list(args)
    subprocess.run(cmd, check=True)


def _ptvsd_so(python_version, *args):
    args = list(args) + ["--limit-time-real=1000", "--limit-time-cpu=600"]
    _so_checker(*args)
    cmd = _so_builder(*args)
    cmd = cmd.split()
    if python_version == PYTHON3:
        ptvsd3(*cmd)
    else:
        ptvsd2(*cmd)


@call_from_shell
def ptvsd2_so(*args):
    _ptvsd_so(PYTHON2, *args)


@call_from_shell
def ptvsd3_so(*args):
    _ptvsd_so(PYTHON3, *args)


@shell_end_hook
@call_from_shell
def go(*args):
    """switch branch for all odoo repos"""
    print("cleaning all the junk")
    clear_pyc()
    params = {"checkout": True, "<version>": args}
    _git_odoo_app(**params)
    # if len(args) == 1:
    #     differed_sh_run(f"go_venv {args[0]}")
    print("-----------")
    differed_sh_run("golist")


@shell_end_hook
@call_from_shell
def go_update_and_clean(version=None):
    """git pull on all the repos of the main source folder (except for support-tools)"""
    params = {"pull": True, "--version": version}
    _git_odoo_app(**params)
    clear_pyc()
    # differed_sh_run("go_venv_current")
    differed_sh_run("echo '--------'")
    differed_sh_run("golist")


@shell_end_hook
@call_from_shell
def godb(db_name):
    """switch repos branch to the version of the given DB"""
    try:
        _ = _get_version_from_db(db_name)
    except OperationalError:
        print(f"DB {db_name} does not exist")
    else:
        params = {"checkout": True, "--dbname": db_name}
        _git_odoo_app(**params)
        # differed_sh_run(f"go_venv {version}")


@shell_end_hook
@call_from_shell
def goso(db_name, *args):
    """switch repos to the version of given db and starts it"""
    godb(db_name)
    so(db_name, *args)


@shell_end_hook
@call_from_shell
def goto(version=None):
    """
    change the current directory to the multiverse branch for the given version
    or to some short-cut often travelled other location
    """
    special_paths = {
        "src": "$SRC",
        "master": "$SRC_MULTI/master",
        "internal": "$INTERNAL",
        "sh": "$PAAS",
        "apps_store": "$INTERNAL/private/loempia",
        "oes": "$ST",
        "ap": "$AP",
        "all_apps_list": "$SRC/all_standard_odoo_apps_per_version",
    }
    short_cuts = [k for k in special_paths]
    if version == "--list-short-cut":
        # for the completion script
        print(" ".join(short_cuts))
        return
    # create short versions of the short cuts (`special_paths`)
    for short_cut in short_cuts:
        # all possible shortened versions of `short_cut`
        super_shorts = [short_cut[0 : i + 1] for i in range(len(short_cut) - 1)]
        for super_short in super_shorts:
            # check for conflicts with any existing shortcuts, except the current one
            conflicts = [k.startswith(super_short) for k in short_cuts if not k == short_cut]
            if not any(conflicts):
                special_paths[super_short] = special_paths[short_cut]

    # get the right path
    path = special_paths.get(version, None)
    try:
        float_version = float(version)
        if int(float_version) == float_version:
            # xx.0 version
            path = f"$SRC_MULTI/{float_version}"
        else:
            # saas-xx.y version
            path = f"$SRC_MULTI/saas-{float_version}"
    except (ValueError, TypeError):
        # version is not a number, or no version was given
        # fall back to the no match found path
        pass
    if path is None:
        print(f"no match found for {version}")
        path = "$SRC"

    # do the thing
    differed_sh_run(f"cd {path}")
    differed_sh_run("echo current folder $(pwd)")


@shell_end_hook
@call_from_shell
def dropodoo(*dbs):
    """drop the given DB(s) and remove its filestore,
    also removes it from meta if it was a local saas db
    dropodoo <db_name(s)>"""
    from shutil import rmtree

    import appdirs

    if not dbs:
        raise Invalid_params(
            """\
            Requires the name(s) of the DB(s) to drop
            dropodoo <db_name(s)>"""
        )
    protection_file = f"{env.AP}/drop_protected_dbs.txt"
    with open(protection_file, "r") as f:
        drop_protected_dbs = [db.strip() for db in f]
    odev_dbs_file = os.path.expanduser("~/.config/odev/databases.cfg")
    odev_dbs_config = ConfigParser()
    odev_dbs_config.read(odev_dbs_file)
    odev_dbs = odev_dbs_config.sections()
    for db in dbs:
        if db in drop_protected_dbs:
            raise Invalid_params(
                f"""\
                DB {db} is drop protected --> aborting
                To override protection, modify the protection file at {protection_file}"""
            )
        # remove from meta
        psql("meta", f"DELETE FROM databases WHERE name = '{db}'", ignore_error=True)
        # dropping
        if db in odev_dbs:
            print(f"Dropping the DB {db} using odev")
            differed_sh_run(f"odev remove {db} -y")
        elif db.startswith("oes_"):
            print(f"Dropping the DB {db} using oe-support")
            differed_sh_run(f"oes cleanup {db[4:]}")
        else:
            psql(
                "postgres",
                f"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '{db}'",
            )
            sh_run(f"dropdb {db}")
            FS_DIR = os.path.join(appdirs.user_data_dir("Odoo"), "filestore")
            filestore_path = os.path.expanduser(os.path.join(FS_DIR, db))
            try:
                rmtree(filestore_path)
            except FileNotFoundError:
                print("failed to delete the filestore, looks like it doesn't exist anymore")


@call_from_shell
def go_fetch():
    # git fetch on all the repos of the main source folder
    _git_odoo_app(fetch=True)


#  vvvvvv   not strictly odoo   vvvvvvv


@call_from_shell
def shurl(long_url):
    """Returns (and prints) a short (and tracked) url version of a link.
    Hosted on an odoo saas server"""
    import keyring

    api_login = env.SHORT_URL_LOGIN
    api_key = keyring.get_password("shurl", api_login)
    assert all((api_key, api_login))
    dburl = "https://shorturl.moens.xyz"
    db = "runboot"
    r_exec = _get_xmlrpc_executer(dburl, db, api_login, api_key)
    data = {"url": long_url}
    url_id = r_exec("link.tracker", "create", [data])
    short_url = r_exec(
        "link.tracker",
        "search_read",
        [[["id", "=", url_id]]],
        {"fields": ["short_url"]},
    )[0]["short_url"]
    # force the "right" domain
    short_url = short_url.replace("runboot.odoo.com", "shorturl.moens.xyz")
    short_url = short_url.replace("totd.moens.xyz", "shorturl.moens.xyz")
    print(short_url)
    return short_url


@call_from_shell
def o_emp(*trigrams):
    """open the employee page for the given trigrams
    also handles github account

    usage:
        o_emp <trigrams>...
    """
    # import webbrowser

    if not trigrams:
        raise Invalid_params("`trigrams` parameter is mandatory. check --help")
    r_exec = _xmlrpc_odoo_com()
    f_trigrams = (f"{trigram.lower()}@odoo.com" for trigram in trigrams)
    mail_domain = ["|"] * (len(trigrams) - 1)
    mail_domain += [["work_email", "=", tri] for tri in f_trigrams]
    github_domain = ["|"] * (len(trigrams) - 1)
    github_domain += [["github_login", "=ilike", tri] for tri in trigrams]  # make it case insensitive
    domain = ["|"] + mail_domain + github_domain
    employees_data = r_exec(
        "hr.employee.public",
        "search_read",
        [domain],
        {
            "fields": [
                "id",
                "name",
                "create_date",
                "department_id",
                "job_title",
                "company_id",
                "parent_id",
                "github_login",
                "user_id",
            ]
        },
    )
    # get data of all managers chains
    managers_data = {
        e["id"]: {"name": e["name"], "parent_id": e["parent_id"] and e["parent_id"][0], "github": e["github_login"]}
        for e in employees_data
    }
    while managers_to_do := [
        e["parent_id"] for _, e in managers_data.items() if e["parent_id"] and e["parent_id"] not in managers_data
    ]:
        new_managers = r_exec(
            "hr.employee.public",
            "search_read",
            [[["id", "in", managers_to_do]]],
            {"fields": ["id", "name", "parent_id", "github_login"]},
        )
        for m in new_managers:
            mm = m["parent_id"] and m["parent_id"][0]
            managers_data[m["id"]] = {"name": m["name"], "parent_id": mm, "github": m["github_login"]}
    # build manager chains
    chains = {id: [e["parent_id"]] for id, e in managers_data.items()}
    while chains_to_do := [id for id, c in chains.items() if c[-1]]:
        for c in reversed(chains_to_do):
            if c in chains[c]:
                # end condition for employee that are their own manager
                chains[c] += [None]
            else:
                chains[c] += chains[chains[c][-1]]
    chains_str = dict()
    for e_id, c in chains.items():
        c.pop()
        parent_loop_min_length = 2
        if len(c) >= parent_loop_min_length and c[-1] == c[-2]:
            # remove last employee of the chain if they are their own manager
            c.pop()
        chains_str[e_id] = " > ".join(f'{managers_data[id]["name"]} [{managers_data[id]["github"]}]' for id in c)
    # get support level
    support_groups = r_exec(
        "res.groups",
        "search_read",
        [[["category_id.name", "=", "Odoo Support Level"]]],
        {"fields": ["id", "name", "users"]},
    )
    levels = [[sg["name"], sg["users"]] for sg in support_groups]
    levels.sort(key=lambda x: len(x[1]))
    # output
    url_template = "https://www.odoo.com/web?debug=1#id={id}&model=hr.employee.public&view_type=form"
    for emp in employees_data:
        for level_name, level_users in levels:
            if emp["user_id"] and emp["user_id"][0] in level_users:
                employee_support_level = level_name
                break
        else:
            employee_support_level = "None"
        print(
            f"""name : {emp['name']}
        github account: {emp['github_login']}
        create date : {emp['create_date']}
        company : {emp['company_id'][1]}
        department : {emp['department_id'] and emp['department_id'][1]}
        Job title : {emp['job_title']}
        Support Level : {employee_support_level}
        managers : {chains_str[emp['id']]}"""
        )
        url = url_template.format(id=emp["id"])
        print("--> ", url)
        # webbrowser.open(url)
    if len(employees_data) == len(trigrams):
        return
    # something went wrong
    if len(employees_data) < len(trigrams):
        msg = "\n\n\nLooks like some employee(s) could not be found"
    else:
        msg = "\n\n\nLooks like some trigram(s) matches multiple employees"
    debug_info = f"""
        requested trigrams: {trigrams}
        domain of the request: {domain}
        results: {employees_data}
        """
    raise Invalid_params(msg + debug_info)


@call_from_shell
def o_user(*trigrams):
    """provides a link to the odoo.com page for the given users
    trigrams is a list of trigrams or user ids

    usage:
        o_user  [<trigrams>...]
    """
    import webbrowser

    def _isint(s):
        try:
            int(s)
            return True
        except ValueError:
            return False

    uids = [uid for uid in trigrams if _isint(uid)]
    f_trigrams = [f"{trigram.lower()}@odoo.com" for trigram in trigrams if not _isint(trigram)]
    users = {}
    if f_trigrams:
        domain = ["|"] * (len(f_trigrams) - 1)
        domain += [["login", "=", tri] for tri in f_trigrams]
        r_exec = _xmlrpc_odoo_com(fallback_to_test=False)
        users_data = r_exec(
            "res.users",
            "search_read",
            [domain],
            {"fields": ["id", "login"]},
        )
        users = {user["id"]: user["login"] for user in users_data}
    else:
        domain = []
    url_template = "https://www.odoo.com/web?debug=1#id={id}&action=17&model=res.users&view_type=form"
    urls = [url_template.format(id=uid) for uid in list(users) + uids]
    print(users)
    for url in urls:
        if uids:
            webbrowser.open(url)
        print(url)
    if len(urls) != len(trigrams):
        msg = "\n\n\nLooks like some user(s) could no be found"
        debug_info = f"""
            requested trigrams: {trigrams}
            domain of the request: {domain}
            results: {users}
            """
        raise Invalid_params(msg + debug_info)


@call_from_shell
def o_apps(*apps_tech_names):
    """
    list apps store apps grouped by versions, and with an short cut vim command to check them on the server
    usage:
        o_apps  [<app_tech_name>...]
    """
    r_exec = _xmlrpc_apps()
    assert len(apps_tech_names), "give the name of at least one app"
    domain = ["|"] * (len(apps_tech_names) - 1)
    domain += [["name", "=", app] for app in apps_tech_names]
    apps: list[dict] = r_exec("loempia.module", "search_read", [domain], {"fields": ["name", "repo_id", "series_id"]})
    repos: list[dict] = r_exec(
        "loempia.repo", "search_read", [[["id", "in", [app["repo_id"][0] for app in apps]]]], {"fields": ["path"]}
    )
    repos_paths = {r["id"]: r["path"] for r in repos}
    per_series = lambda x: x.get("series_id")
    apps.sort(key=per_series)
    for serie, apps_v in groupby(apps, key=per_series):
        print(f"{serie[1]} :")
        paths = []
        for app in apps_v:
            # print(app)
            app_path = repos_paths[app["repo_id"][0]] + "/" + app["name"]
            print(app_path)
            paths.append(app_path)
        first = paths[0]
        splits = [f"-c ':vsplit {p}'" for p in paths[1:]]
        vim_cmd = f"view {first} {' '.join(splits)} -c ':nnoremap - :Explore<CR>'"
        print(vim_cmd)


@call_from_shell
def o_ver(domain, *args, verbose=True):
    """returns versions information about an odoo database, given a domain name"""
    from xmlrpc.client import ProtocolError
    from xmlrpc.client import ServerProxy as server

    from requests import get

    try:
        version_info = server(f"https://{domain}/xmlrpc/2/common").version()
    except ProtocolError:
        # probably redirected
        url = get(f"https://{domain}").url  # requests follows redirections
        version_info = server(f"{url}xmlrpc/2/common").version()
    except gaierror:
        # socket.gaierror: [Errno 8] nodename nor servname provided, or not known
        domain = f"{domain}.odoo.com"
        version_info = server(f"https://{domain}/xmlrpc/2/common").version()

    if "--short" in args:
        version_info = version_info["server_serie"]
        float(version_info)

    if verbose:
        print(version_info)
    return version_info


@cache
def _clean_db_name_and_server(name):
    name = name.removesuffix(".odoo.com")
    out = sh_run(f"dig {name}.odoo.com mx +short")
    if out:
        db = name
        server = out.split()[-1].rstrip(".").removesuffix(".odoo.com")
    else:
        db = None
        server = name
    return (db, server)


@call_from_shell
def o_loc(db):
    """Get the hosting location of the database, as well as the location of the backup servers"""
    _, server = _clean_db_name_and_server(db)
    server = f"{server}.odoo.com"
    r_exec = _xmlrpc_master()
    domain = [["name", "=", server]]
    odoo_server = r_exec("saas.server", "search_read", [domain], {"fields": ["backup_group_id", "dc_id"]})
    print("\nodoo server:")
    print(f"{server} --> {odoo_server[0]['dc_id'][1]}")
    backup_group = odoo_server[0]["backup_group_id"]
    bak_domain = [["backup_group_id", "=", backup_group[0]], ["mode", "like", "bak"]]
    backup_servers = r_exec("saas.server", "search_read", [bak_domain], {"fields": ["name", "dc_id"]})
    print("\nbackup servers:")
    print("\n".join(f'{bak["name"]} --> {bak["dc_id"][1]}' for bak in backup_servers))


@call_from_shell
def o_size(db):
    """get the size of a saas database"""
    db, server = _clean_db_name_and_server(db)
    _, ssh = _ssh_executor(server)
    if not ssh:
        return False
    sql_query = f"SELECT pg_size_pretty(pg_database_size('{db}'));"
    psql_cmd = f'psql -tAqX -d {db} -c "{sql_query}"'
    _, stdout, _ = ssh(psql_cmd)
    sql_size = stdout.readline().rstrip()
    filestore_size_cmd = f"du -sh /home/odoo/filestore/{db}/"
    _, stdout, _ = ssh(filestore_size_cmd)
    filestore_size = stdout.readline().split()[0]
    print("SQL Size:", sql_size)
    print("Filestore Size:", filestore_size)
    return True


@call_from_shell
def o_freespace(server):
    """get the availlable disk space of on saas server"""
    _, server = _clean_db_name_and_server(server)
    _, ssh = _ssh_executor(server)
    if not ssh:
        return False
    _, stdout, _ = ssh("df -h")
    columns = stdout.readline()
    clean_columns = columns.replace("%", "").replace(" on", "_on")
    df_line = namedtuple("df_line", clean_columns.split())
    print("Mounted on\t\tUsed\tAvail\tUse%")
    for line in stdout.readlines():
        line = df_line(*line.rstrip().split())
        if "home" in line.Mounted_on and ".zfs/snapshot/" not in line.Mounted_on:
            tabs_rules = {(0, 6): 3, (6, 15): 2, (15, 999): 1}
            tabs_nb = next(v for k, v in tabs_rules.items() if k[0] < len(line.Mounted_on) < k[1])
            tabs = tabs_nb * "\t"
            print(f"{line.Mounted_on}{tabs}{line.Used}\t{line.Avail}\t{line.Use}")
    return True


@call_from_shell
def o_meta(db):
    """get the size of a saas database"""
    db, server = _clean_db_name_and_server(db)
    _, ssh = _ssh_executor(server)
    if not ssh:
        return False
    meta_get_cmd = f"/home/odoo/bin/oe-meta get -j {db} | jq"
    _, stdout, _ = ssh(meta_get_cmd)
    print("\nMeta info:")
    print("".join(stdout.readlines()))
    return True


@call_from_shell
def o_stat(db):
    """Show location, and size of a db and disk usage stat of the server"""
    from xmlrpc.client import ProtocolError

    db, server = _clean_db_name_and_server(db)
    if db:
        try:
            o_ver(db)
        except ProtocolError:
            # probably a timeout (redirections are already handled by o_ver)
            print("failed to get database version")
        o_size(db)
        o_meta(db)
    o_loc(server)
    print()
    o_freespace(server)


@shell_end_hook
@call_from_shell
def our_modules_update_and_compare():
    cmds = """cd $ST/scripts/clean_database_helper/
    ./Our_modules_generator.py --update-branches
    """
    differed_sh_run(cmds)


@call_from_shell
def digfresh(domain, *records):
    """Query DNS record against the authorative server to avoid cache issue
    digfresh <domain_to_query> [<dns_records_to_check>...]
    """
    ns_raw = sh_run(f"dig {domain} NS +short")
    ns = [e for e in ns_raw.split("\n") if e][0]
    if ns.endswith(".odoo.com."):
        ns = "master.odoo.com."
    print("Authoritative server: ", ns)
    for record in records:
        print(record, ":")
        res_raw = sh_run(f"dig @{ns} {domain} {record} +short")
        print(res_raw)
        if not res_raw:
            # no result for the authoritative server
            # display the normal dig result
            res_raw2 = sh_run(f"dig {domain} {record} +short")
            print(f"Non authoritatitve result for {record}:")
            print(res_raw2)


# -----  simple tests -----


@shell_end_hook
@call_from_shell
def dummy_command():
    """Just a dummy command"""
    print("in python")
    differed_sh_run("echo 'in shell'")
    dummy_nested_function()


@shell_end_hook
@call_from_shell
def dummy_nested_function():
    differed_sh_run("echo 'in shell, from nested'")


# ^^^^^^^^^^^ aliasable functions above this line ^^^^^^^^^

####################################
#  common typo and simple aliases  #
####################################


def typos_and_simple_aliases():
    typos_dict = {
        "clear": [
            "clera",
            "clea",
            "cleare",
            "cleazr",
            "clearr",
            "cllear",
            "clear$",
            "claer",
            "cmear",
            "cldear",
            "cler",
            "cear",
            "clar",
        ],
        "new_typo": ["new_ypo", "new_tupo", "new_ytpo", "newtypo"],
        "e .": ["e.", ".e"],
        "exit": [
            "exiit",
            "exit$",
            "exiy",
            "exitt",
            "exirt",
            "exir",
            "exut",
        ],
        "eza": ["eaz", "za", "ez"],
        "ezatig": ["ezatgi", "eaztgi"],
        "git": ["gti"],
        "htop": ["hotp"],
        "oes": ["eos", "ose", "oe", "eso"],
        "open .": ["open."],
        "pl": ["pl$"],
        "python": ["pyhton"],
        "python3": ["pyhton3"],
        "runbot": ["runbit"],
        "ssh": ["shh"],
        "tig": ["tgi", "tig$", "tog"],
        "which": ["whicj"],
    }

    simple_aliases = {
        "clean_database": "$ST/clean_database.py",
        "date": "gdate",
        "dbd": "cd $DBD",
        "debo": "ptvsd3_so",
        "debo2": "ptvsd2_so",
        "ewq": "eza",
        "ezagit": "git -C $AP",
        "ezatig": "tig -C $AP",
        "file_server": "$SRC/misc_gists/simple_file_server/http_server_auth.py",
        "find_backup": "$PSS/find_backup.py",
        "gov": "go_venv",
        "govcur": "go_venv_current",
        "neuter_db": "$ST/lib/neuter.py",
        "odoosh": "$ST/scripts/odoosh/odoosh.py",
        "oe-support": "oes",
        "python3.10": "/usr/local/opt/python@3.10/bin/python3.10",
        "python3.7": "/usr/local/opt/python@3.7/bin/python3.7",
        "python3.9": "/usr/local/opt/python@3.9/bin/python3.9",
        "runbot": "build_runbot",
        "ssl_checker": "$PSS/SSL_checker.py",
        "thingsToDiscussAtNextSquadMeeting": "e ~/Documents/meetings_notes/thingsToDiscussAtNextSquadMeeting.txt",
        "xdg-open": "open",
        "apikey_rotation": "$ST/lib/apikey_rotation/app.py",
    }

    # reverse mappping (and remove duplicates)
    alias_dict = {typo: good for good, typos in typos_dict.items() for typo in typos}

    alias_dict.update(simple_aliases)

    # done this way to enbale syntaxe highlighting with Zsh-syntax-highlighting
    # (it fails with some aliases, not sure what's the root cause)
    # and autocompletion
    # (the one that fail the highlight also fail to complete)
    templ = "{typo} () {{ {good} $@  }}\n"
    return [templ.format(typo=t, good=g) for t, g in alias_dict.items()]
    # return [f"alias '{typo}'='{good}'\n" for typo, good in alias_dict.items()]


def generate_aliases():
    shell_function_template = """{fname}() {{
        $AP/python_scripts/alias.py {fname} $@\
        {diff_exec}
    }}
\n"""

    aliases = []
    for fname in CALLABLE_FROM_SHELL:
        differed_execution_code = differed_code_execution_generator(fname)
        diff_exec = differed_execution_code if fname in SHELL_END_HOOK else ""
        aliases.append(shell_function_template.format(fname=fname, diff_exec=diff_exec))

    aliases += typos_and_simple_aliases()

    # path to the automatically generated scripts
    auto_script_path = f"{env.AP}/autogenerated_scripts.sh"
    with open(auto_script_path, "w") as f:
        for a in aliases:
            f.write(a)


if __name__ == "__main__":
    if len(sys.argv) <= 1:
        print("Missing arguments, require at least the function name")
        sys.exit(1)

    method_name = sys.argv[1]
    if method_name == "--generate":
        generate_aliases()
        sys.exit(0)

    assert method_name in CALLABLE_FROM_SHELL
    method_params = sys.argv[2:]
    if "--help" in method_params and method_name not in IGNORE_GENERIC_HELP:
        custom_help = CALLABLE_FROM_SHELL[method_name].__doc__
        func_sign = str(signature(CALLABLE_FROM_SHELL[method_name]))
        pretty_func_sign = f"{method_name}{func_sign}"
        print(custom_help or f"No doc availlable\n {pretty_func_sign}")
        sys.exit(0)

    try:
        res = CALLABLE_FROM_SHELL[method_name](*method_params)
        if res is False:
            sys.exit(1)
    except (Invalid_params, UserAbort) as nice_e:
        cancel_pending_commands(method_name)
        print(nice_e)
        sys.exit(1)
    except Exception:
        cancel_pending_commands(method_name)
        raise
