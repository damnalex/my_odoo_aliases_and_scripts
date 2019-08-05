#!/usr/bin/env python3
"""
start_odoo

usage:
    start_odoo <dbname> [--port <port_nb>] [--checkout --ptvsd] [-u <modules_to_update> ... | -i <modules_to_install> ...] [--saas] [--stop-after-init]

options:
    --port=<port_nb>
    -u=<modules_to_update>
    -i=<modules_to_install>
"""

from docopt import docopt
from .git_odoo import _get_version_from_db as db_version
from .git_odoo import odoo_repos_checkout


def repo_is_correct_version(dbname):
    """ returns True if the repo checked out version is the same as the database version.
    return False otherwise.
    """
    raise NotImplementedError


def ask_user_to_checkout():
    """ interactive prompt that gives the opportunity to the user to checkout
    the right version of the odoo repos."""
    raise NotImplementedError
    # 3 options : yes (continues as is), no (aborts the process), checkout (checkouts the right version and continues)

def build_command(someargs_TODO):
    """ build a shell command usable by subprocess.call (in a list of strings, one string = one word) """
    raise NotImplementedError

def run_command(cmd, some_other_args):
    """ run the odoo server, with the optionnal setup needed for the options:
        - saas
    """
    raise NotImplementedError

def main():
    # args parsing
    opt = docopt(__doc__)
    print(opt)

    if opt.get('--checkout'):
        # checkout the right version
        raise NotImplementedError
    elif not repo_is_correct_version(opt.get('<dbname>')):
        ask_user_to_checkout()

    cmd = build_command(someargs_TODO)
    run_command(cmd, some_other_args)

if __name__ == "__main__":
    main()
