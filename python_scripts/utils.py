import os
import xmlrpc.client
from functools import partial
from typing import Sequence


class EnvironmentExtractor:
    """Recovers any environment variables.
    Once called, self.XXX stores the environment variable XXX value,
    for faster subsequent calls"""

    def __getattr__(self, name):
        """Will only be called the first time self.XXX is called"""
        env_var = os.getenv(name)
        if not env_var:
            raise ValueError(f"No value found for environment variable {name}")
        setattr(self, name, env_var)
        return env_var


env = EnvironmentExtractor()


def _get_xmlrpc_executer(dburl, dbname, login, password):
    """return a function that executes xml_rpc calls on a given odoo db"""
    common = xmlrpc.client.ServerProxy("{}/xmlrpc/2/common".format(dburl))
    models = xmlrpc.client.ServerProxy("{}/xmlrpc/2/object".format(dburl))
    uid = common.authenticate(dbname, login, password, {})
    # TODO: Find a better technically correct type hint for this
    # but for now , it will do the job good enough to get linters
    # to calm down in the rest of the scripts
    r_exec: partial[Sequence] = partial(models.execute_kw, dbname, uid, password)
    return r_exec


def _xmlrpc_odoo_com(fallback_to_test=True):
    import keyring

    api_key = keyring.get_password("oe-support", "mao@odoo.com-2FA")
    api_login = "mao@odoo.com"
    assert all((api_key, api_login))
    db = "openerp"
    fallbacks = [
        "https://www.odoo.com",  # the prod
        "https://www.test.odoo.com",
        "https://staging1.test.odoo.com",
        "https://staging2.test.odoo.com",
        "https://staging3.test.odoo.com",
        "https://staging4.test.odoo.com",
        "https://staging5.test.odoo.com",
        "https://staging6.test.odoo.com",
        "https://staging7.test.odoo.com",
    ]
    for fallback in fallbacks:
        dburl = fallback
        r_exec = _get_xmlrpc_executer(dburl, db, api_login, api_key)
        try:
            # just a test request
            r_exec("res.users", "search_read", [[["login", "=", "mao@odoo.com"]]], {"fields": ["id"]})
        except xmlrpc.client.ProtocolError:
            pass
            if not fallback_to_test:
                raise
        else:
            if fallback != fallbacks[0]:
                print(f"WARNING : Using {fallback} as the xmlrpc connector")
            return r_exec
    raise xmlrpc.client.ProtocolError("all fallbacks failed")


def _xmlrpc_master():
    import keyring

    api_key = keyring.get_password("find_backup_master_2FA", "mao@odoo.com")
    api_login = "mao@odoo.com"
    assert all((api_key, api_login))
    db_url = "https://master.odoo.com"
    db_name = "saas_master"
    r_exec = _get_xmlrpc_executer(db_url, db_name, api_login, api_key)
    return r_exec


def _xmlrpc_apps():
    import keyring

    api_key = keyring.get_password("apps-hunter", "mao@odoo.com-2FA")
    api_login = "mao@odoo.com"
    assert all((api_key, api_login))
    db_url = "https://apps.odoo.com"
    db_name = "apps"
    r_exec: callable[list] = _get_xmlrpc_executer(db_url, db_name, api_login, api_key)
    return r_exec
