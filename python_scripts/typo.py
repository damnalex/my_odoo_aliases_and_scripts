#!/usr/bin/env python3

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
    "oes": ["eos", "ose", "oe", "eso", "oe-support"],
    "eza": ["eaz", "za", "ez"],
    "exit": ["exiit", "exit$", "exiy", "exitt", "exirt"],
    "clear": [
        "clera",
        "clea",
        "cleare",
        "cleazr",
        "clearr",
        "cllear",
        "clear$",
        "claer",
    ],
    "new_typo": ["new_ypo", "new_tupo", "new_ytpo"],
}

simple_aliases = {
    "clean_database": "$ST/clean_database.py",
    "odoosh": "$ST/odoosh/odoosh.py",
    "debo2": "ptvsd2_so",
    "debo": "ptvsd3_so",
    "gov": "gov_venv",
    "govcur": "go_venv_current",
    "runbot": "build_runbot",
}

for k, v in simple_aliases.items():
    if not typos_dict.get(v):
        typos_dict[v] = [k]
    else:
        typos_dict[v].append(k)


typo_alias_list = []
# building the aliases
for good, typos in typos_dict.items():
    for typo in typos:
        alias = f"""alias '{typo}'='{good}'\n"""
        typo_alias_list.append(alias)
