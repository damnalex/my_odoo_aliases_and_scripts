#!/usr/bin/env python3
from collections import defaultdict

# common typo and simple aliases

typos_dict = {
    "git": ["gti"],
    "python3": ["pyhton3"],
    "python": ["pyhton"],
    "l": ["l$"],
    "ssh": ["shh"],
    "which": ["whicj"],
    "htop": ["hotp"],
    "pl": ["pl$"],
    "runbot": ["runbit"],
    "tig": ["tgi", "tig$", "tog"],
    "oes": ["eos", "ose", "oe", "eso"],
    "eza": ["eaz", "za", "ez"],
    "ezatig": ["ezatgi", "eaztgi"],
    "exit": ["exiit", "exit$", "exiy", "exitt", "exirt"],
    "clear": [
        "c",
        "clera",
        "clea",
        "cleare",
        "cleazr",
        "clearr",
        "cllear",
        "clear$",
        "claer",
        "cmear",
        "cldear",
        "cler",
    ],
    "new_typo": ["new_ypo", "new_tupo", "new_ytpo", "newtypo"],
}

simple_aliases = {
    "clean_database": "$ST/clean_database.py",
    "odoosh": "$ST/odoosh/odoosh.py",
    "neuter_db": "$ST/tools/neuter.py",
    "debo2": "ptvsd2_so",
    "debo": "ptvsd3_so",
    "gov": "go_venv",
    "govcur": "go_venv_current",
    "runbot": "build_runbot",
    "oe-support": "oes",
    "ezagit": "git -C $AP",
    "python3.7": "/usr/local/opt/python@3.7/bin/python3.7",
}

# include simple aliases in typos_dict
typos_dict = defaultdict(list, typos_dict)
for k, v in simple_aliases.items():
    typos_dict[v].append(k)

# fmt: off

# remove unintentionnal duplicates
typos_dict = {
    k: set(v)
    for k, v in typos_dict.items()
}

typo_alias_list = [
    f"alias '{typo}'='{good}'\n"
    for good, typos in typos_dict.items()
    for typo in typos
]
# fmt: on
