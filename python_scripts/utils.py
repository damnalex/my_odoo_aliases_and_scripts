import os
import collections

# environment variables
env = [
    "AP",
    "SRC",
    "ODOO",
    "ENTERPRISE",
    "INTERNAL",
    "ST",
    "SRC_MULTI",
    "ODOO_STORAGE",
    "PAAS",
    "DESIGN_THEMES",
]
env = {e: os.getenv(e) for e in env}
EnvTuple = collections.namedtuple("Env", " ".join(env.keys()))
env = EnvTuple(**env)
# env.XXX now stores the environment variable XXX
