#!/usr/bin/env python3
import sys
import os

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


# ^^^^^^^^^^^ aliasable functions above this line ^^^^^^^^^

if __name__ == "__main__":
    if len(sys.argv) > 1:
        method_name = sys.argv[1]
        method_params = sys.argv[2:]
        method_params = ", ".join(f"'{param}'" for param in method_params)
        eval(f"{method_name}({method_params})")
    else:
        print("Missing arguments, require at least the function name")
