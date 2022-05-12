#!/usr/bin/env python3
import sys
import os
import collections
import subprocess
from textwrap import dedent as _dd
from psycopg2 import OperationalError, ProgrammingError, connect
from inspect import signature

from utils import env
from git_odoo import _repos, _get_version_from_db, App as _git_odoo_app


########################
#   decorators stuff   #
########################

IGNORE_GENERIC_HELP = set()
CALLABLE_FROM_SHELL = dict()
SHELL_END_HOOK = set()
SHELL_DIFFERED_COMMANDS_FILE = f"{env.AP}/differed_commands.txt"
differed_sh_run_new_batch = True


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


def differed_sh_run(cmd):
    # prepare a command to be executed after the end of the python script
    # can only work in functions decorated with `shell_end_hook` and `call_from_shell`
    # or called by functions decorated with `shell_end_hook` and `call_from_shell`
    global differed_sh_run_new_batch
    write_mode = "w" if differed_sh_run_new_batch else "a"
    with open(SHELL_DIFFERED_COMMANDS_FILE, write_mode) as f:
        f.write(cmd + "\n")
    differed_sh_run_new_batch = False


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
    """switch branch for all odoo repos"""
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
    """git pull on all the repos of the main source folder (except for support-tools)"""
    params = {"pull": True, "--version": version}
    _git_odoo_app(**params)
    clear_pyc()
    differed_sh_run("go_venv_current")
    differed_sh_run("echo '--------'")
    differed_sh_run("golist")


@shell_end_hook
@call_from_shell
def godb(db_name):
    """switch repos branch to the version of the given DB"""
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
    """switch repos to the version of given db and starts it"""
    godb(db_name)
    so(db_name, *args)


@shell_end_hook
@call_from_shell
def dropodoo(*dbs):
    """drop the given DB(s) and remove its filestore,
    also removes it from meta if it was a local saas db
    dropodoo <db_name(s)> """
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
        psql("meta", f"DELETE FROM databases WHERE name = '{db}'", ignore_error=True)
        # dropping
        if db.startswith("oes_"):
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
                print(
                    "failed to delete the filestore, looks like it doesn't exist anymore"
                )


@call_from_shell
def go_fetch(*args):
    # git fetch on all the repos of the main source folder
    _git_odoo_app(fetch=True)


#  vvvvvv   not strictly odoo   vvvvvvv


def _get_xmlrpc_executer(dburl, dbname, login, password):
    """return a function that executes xml_rpc calls on a given odoo db"""
    import xmlrpc.client
    from functools import partial

    common = xmlrpc.client.ServerProxy("{}/xmlrpc/2/common".format(dburl))
    models = xmlrpc.client.ServerProxy("{}/xmlrpc/2/object".format(dburl))
    uid = common.authenticate(dbname, login, password, {})
    r_exec = partial(models.execute_kw, dbname, uid, password)
    return r_exec


def _xmlrpc_odoo_com():
    import keyring

    api_key = keyring.get_password("oe-support", "mao-2FA")
    api_login = "mao"
    assert all((api_key, api_login))
    dburl = "https://www.odoo.com"
    db = "openerp"
    r_exec = _get_xmlrpc_executer(dburl, db, api_login, api_key)
    return r_exec


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

    usage:
        o_emp trigrams...
    """
    import webbrowser

    if not trigrams:
        raise Invalid_params("`trigrams` parameter is mandatory. check --help")
    r_exec = _xmlrpc_odoo_com()
    f_trigrams = (f"({trigram.lower()})" for trigram in trigrams)
    domain = ["|"] * (len(trigrams) - 1)
    domain += [["name", "like", tri] for tri in f_trigrams]
    employees_data = r_exec(
        "hr.employee.public",
        "search_read",
        [domain],
        {"fields": ["id", "name", "create_date"]},
    )
    url_template = "https://www.odoo.com/web?debug=1#id={id}&model=hr.employee.public&view_type=form"
    for emp in employees_data:
        print(f"name : {emp['name']}\ncreate date : {emp['create_date']}")
        url = url_template.format(id=emp['id'])
        print("--> ", url)
        webbrowser.open(url)
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
    f_trigrams = [f"{trigram.lower()}" for trigram in trigrams if not _isint(trigram)]
    users = {}
    if f_trigrams:
        domain = ["|"] * (len(f_trigrams) - 1)
        domain += [["login", "=", tri] for tri in f_trigrams]
        r_exec = _xmlrpc_odoo_com()
        users_data = r_exec(
            "res.users",
            "search_read",
            [domain],
            {"fields": ["id", "login"]},
        )
        users = {user["id"]: user["login"] for user in users_data}
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
def o_ver(domain, verbose=True):
    """returns versions information about an odoo database, given a domain name"""
    from xmlrpc.client import ServerProxy as server, ProtocolError
    from requests import get

    try:
        version_info = server(f"https://{domain}/xmlrpc/2/common").version()
    except ProtocolError as pe:
        # probably redirected
        url = get(f"https://{domain}").url  # requests follows redirections
        version_info = server(f"{url}xmlrpc/2/common").version()

    if verbose:
        print(version_info)
    return version_info


@shell_end_hook
@call_from_shell
def our_modules_update_and_compare(*args):
    cmds = """cd $ST/scripts/clean_database_helper/
    ./Our_modules_generator.py --update-branches
    """
    differed_sh_run(cmds)


@shell_end_hook
@call_from_shell
def dummy_command(*args):
    """Just a dummy command"""
    print("in python")
    differed_sh_run("echo 'in shell'")


# ^^^^^^^^^^^ aliasable functions above this line ^^^^^^^^^

####################################
#  common typo and simple aliases  #
####################################


def typos_and_simple_aliases():
    typos_dict = {
        "git": ["gti"],
        "python3": ["pyhton3"],
        "python": ["pyhton"],
        "l": ["l$"],
        "ssh": ["shh"],
        "which": ["whicj"],
        "htop": ["hotp"],
        "pl": ["pl$"],
        "runbot": ["runbit"],
        "tig": ["tgi", "tig$", "tog"],
        "oes": ["eos", "ose", "oe", "eso"],
        "eza": ["eaz", "za", "ez"],
        "ezatig": ["ezatgi", "eaztgi"],
        "exit": [
            "exiit",
            "exit$",
            "exiy",
            "exitt",
            "exirt",
            "exir",
            "exut",
        ],
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
        ],
        "new_typo": ["new_ypo", "new_tupo", "new_ytpo", "newtypo"],
    }

    simple_aliases = {
        "clean_database": "$ST/clean_database.py",
        "odoosh": "$ST/scripts/odoosh/odoosh.py",
        "neuter_db": "$ST/lib/neuter.py",
        "debo2": "ptvsd2_so",
        "debo": "ptvsd3_so",
        "gov": "go_venv",
        "govcur": "go_venv_current",
        "runbot": "build_runbot",
        "oe-support": "oes",
        "ezagit": "git -C $AP",
        "ezatig": "tig -C $AP",
        "python3.7": "/usr/local/opt/python@3.7/bin/python3.7",
        "python3.9": "/usr/local/opt/python@3.9/bin/python3.9",
        "thingsToDiscussAtNextSquadMeeting": "e ~/Documents/meetings_notes/thingsToDiscussAtNextSquadMeeting.txt",
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
    differed_execution_code = f"""
        while read l; do
            eval $l;
        done <{SHELL_DIFFERED_COMMANDS_FILE}
        date >> $AP/differed_commands_history.txt
        cat {SHELL_DIFFERED_COMMANDS_FILE} >> $AP/differed_commands_history.txt
        cp /dev/null {SHELL_DIFFERED_COMMANDS_FILE}
    """

    aliases = []
    for fname in CALLABLE_FROM_SHELL:
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
        CALLABLE_FROM_SHELL[method_name](*method_params)
    except (Invalid_params, UserAbort) as nice_e:
        print(nice_e)
