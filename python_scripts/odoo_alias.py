#!/usr/bin/env python3
import sys
import os
import psycopg2

from git_odoo import _repos, _get_version_from_db

# environment variables
env = dict()
env_vars = [
    "AP",
    "SRC",
    "ODOO",
    "ENTERPRISE",
    "INTERNAL",
    "ST",
    "SRC_MULTI",
    "ODOO_STORAGE",
]
for env_var in env_vars:
    env[env_var] = os.getenv(env_var)

# the params of the public functions are positional, and string only
class Invalid_params(Exception):
    pass


class UserAbort(Exception):
    pass


def _get_branch_name(path):
    # return the name of the current branch of repo :path
    # _repos expects multiple path entries in an itterable
    # giving one in a list
    repo_generator = _repos([path])
    repo = list(repo_generator)[0]
    return repo.active_branch.name


def so_checker(*args):
    if len(args) == 0:
        raise Invalid_params("""
        At least give me a name :(
        so dbname [port] [other_parameters]
        note: port is mandatory if you want to add other parameters
        """)
    db_name = args[0]
    if db_name.startswith("CLEAN_ODOO"):
        raise Invalid_params(f"""
        Don't play with that one!
        {db_name} is a protected database.
        """)
    try:
        db_version = _get_version_from_db(db_name)
    except psycopg2.OperationalError:
        # db doesn't exist.
        pass
    else:
        checked_out_branch = _get_branch_name(env['ODOO'])
        if db_version != checked_out_branch:
            print(f"""
            version mismatch
            DB version is: {db_version}
            repo version is: {checked_out_branch}
            """)
            ans = input("continue anyway? (y/N):").lower()
            if ans == "y":
                print("I hope you know what you're doing...")
            else:
                raise UserAbort("Yeah, that's probably safer :D")


# ^^^^^^^^^^^ aliasable functions above this line ^^^^^^^^^

if __name__ == "__main__":
    if len(sys.argv) > 1:
        method_name = sys.argv[1]
        method_params = sys.argv[2:]
        method_params = ", ".join(f"'{param}'" for param in method_params)
        eval(f"{method_name}({method_params})")
    else:
        print("Missing arguments, require at least the function name")

