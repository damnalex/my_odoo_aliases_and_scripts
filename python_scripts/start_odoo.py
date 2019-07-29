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

def main():
    # args parsing
    opt = docopt(__doc__)
    print(opt)


if __name__ == "__main__":
    main()
