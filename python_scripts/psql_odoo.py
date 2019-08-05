#!/usr/bin/env python3
"""
psql_odoo

usage:
   psql_odoo list [--filter <filter>] [--saas-only]
   psql_odoo drop (<dbname> ... | --like <patern>)
   psql_odoo build_runbot <version> <dbname>

options:
    --filter=<filter>
    --like=<patern>
"""
from docopt import docopt
import psycopg2

def _is_odoo_db(dbname):
    """ Returns True if the database is an odoo database, False otherwise.
    """
    raise NotImplementedError


def _list_db_like(pattern):
    """ returns a list of DB name that match the sql like pattern
    """
    raise NotImplementedError


def list_odoo_dbs(name_filter=None, saas_only=False):
    """ Lists the odoo databases on the system
    if name_filter is provided, only show the DBs that have a name that match the pattern (sql like pattern)
    if saas_only is True, only show the DBs that are listed in the meta base
    """
    raise NotImplementedError


def drop_odoo_dbs(dbs):
    """ Drop the DBs listed in dbs,
    Removes them from the meta base,
    and Deletes the associated filestore
    """
    raise NotImplementedError


def build_runbot(version, dbname):
    """ Builds a pseudo runbot, aka a copy of a reference db with all app installed
    It copies the DB and the associated filestore.
    Side effect : if a DB with the name dbname exists, it will be dropped first
    """
    raise NotImplementedError


def main():
    # args parsing
    opt = docopt(__doc__)

    if opt.get("list"):
        dbfilter = opt.get("--filter")
        saas_only = opt.get("--saas-only")
        list_odoo_dbs(dbfilter, saas_only)

    if opt.get("drop"):
        dbs = opt.get("<dbname>")
        pattern = opt.get("--like")
        if pattern:
            dbs = _list_db_like(pattern)
        drop_odoo_dbs(dbs)

    if opt.get("build_runbot"):
        version = opt.get("<version>")
        new_db_name = opt.get("<dbname>")
        build_runbot(version, new_db_name)


if __name__ == "__main__":
    main()
