#!/usr/bin/python3
import inspect
import types


def extract_public_functions_from_module(module):
    # returns a list of the names of the public functions defined in :module
    mems = inspect.getmembers(module)
    # The folowing 2 operation are technically useless, but it is a good explanation of what I actually want to do
    members_to_ignore = [
        "__builtins__",
        "__cached__",
        "__doc__",
        "__file__",
        "__loader__",
        "__name__",
        "__package__",
        "__spec__",
    ]
    local_members = (m for m in mems if m[0] not in members_to_ignore)
    functions = (f for f in local_members if isinstance(f[1], types.FunctionType))
    return [f[0] for f in functions if not f[0].startswith("_")]


# vvvvvvvvv   build the aliases   vvvvvvvvv

import odoo_alias

odoo_alias_functions = extract_public_functions_from_module(odoo_alias)

for fname in odoo_alias_functions:
    print(f"alias '{fname}'='$AP/python_scripts/odoo_alias.py {fname}';")
