#!/usr/bin/env python3
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
    "clear": ["clera", "clea", "cleare", "cleazr", "clearr", "cllear"],
    "new_typo": ["new_ypo", "new_tupo", "new_ytpo"],
}

typo_alias_list = []
# building the aliases
for good, typos in typos_dict.items():
    for typo in typos:
        alias = f"""alias '{typo}'='{good}'\n"""
        typo_alias_list.append(alias)
