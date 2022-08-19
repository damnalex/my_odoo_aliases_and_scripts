import os


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
