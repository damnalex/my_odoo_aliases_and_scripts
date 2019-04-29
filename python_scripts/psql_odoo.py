#!/usr/bin/env python3
"""
psql_odoo

usage:
   psql_odoo list [--filter <filter>] [--saas-only]
   psql_odoo drop (<dbname> ... | --like <patern>)
   psql_odoo build_runbot <version> <dbname>

"""
from docopt import docopt


