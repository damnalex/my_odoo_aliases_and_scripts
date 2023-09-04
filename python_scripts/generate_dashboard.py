#!/usr/bin/env python3
import uuid

# from utils import _xmlrpc_odoo_com


def uuid_gen():
    return uuid.uuid4().hex


################################################################
#####################    generics    ###########################
################################################################
uid = 963957
allowed_companies = [1, 2, 3, 4, 5, 14, 17]
company_ids_str = ",".join(str(e) for e in allowed_companies)
help_project = 49
squad_to_leader_employee = {
    "varia": 136783,  # mao
    "account": 1490367,  # tbs
    "pos": 715807,  # lse
    "stock": 885,  # nci
    "sm": 317943,  # bve
    "perf": 1206319,  # avd
    "website_js": 1001546,  # pco
}
varia = [
    "gavb",
    "lole",
    "lrfd",
    "mao",
    "nasg",
    "ofa",
    "peso",
    "sigo",
    "syf",
]
account = [
    "amay",
    "arsi",
    "asm",
    "bebo",
    "crm",
    "flhu",
    "mege",
    "sold",
    "tbs",
    "thco",
]
pos = [
    "khah",
    "lse",
    "pebr",
]
stock = [
    "dafr",
    "nci",
    "pno",
    "wama",
    "was",
]
sm = [
    "bve",
    "frc",
    "jorv",
    "yla",
]
perf = [
    "auma",
    "avd",
    "beha",
    "nea",
]
website_js = [
    "jula",
    "pco",
    "thc",
]

other = [
    # BE
    "mvw",
    "jmfa",
    "quvb",
    # US
    "adda",
    "andg",
    "bikh",
    "cyro",
    "dhs",
    "evko",
    "guba",
    "iada",
    "jrbr",
    "jelu",
    "maje",
    "myhy",
    "deni",
    "orzh",
    "pca",
    "qung",
    "prri",
    "ryce",
    "vasu",
    "zaha",
]

match_name_to_squad = {
    "varia": varia,
    "account": account,
    "pos": pos,
    "stock": stock,
    "sm": sm,
    "perf": perf,
    "website_js": website_js,
    "other": other,
}


def get_from_squad(main, not_in=False):
    for name, squad in match_name_to_squad.items():
        if (name == main and not not_in) or (name != main and not_in):
            yield from squad


base_context = {
    "lang": "en_US",
    "tz": "Europe/Brussels",
    "uid": uid,
    "allowed_company_ids": allowed_companies,
}

help_context = base_context.copy()
help_context.update(
    {
        "active_id": help_project,
        "active_ids": [help_project],
        "params": {
            "action": 333,
            "active_id": help_project,
            "cids": company_ids_str,
            "menu_id": 4720,
            "model": "project.task",
            "view_type": "kanban",
        },
        "pivot_row_groupby": ["user_ids"],
        "default_project_id": help_project,
        # 'group_by': ['date_last_stage_update:month', 'create_date:month'],
        "orderedBy": [],
        "graph_measure": "__count__",
        "graph_mode": "bar",
        # 'graph_groupbys': ['date_last_stage_update:month'],
        "dashboard_merge_domains_contexts": False,
    }
)

groupby_stage_update_and_create = {
    "group_by": ["date_last_stage_update:week", "create_date:month"],
    "graph_groupbys": ["date_last_stage_update:week", "create_date:month"],
}

groupby_stage_update_and_stage = {
    "group_by": ["date_last_stage_update:month", "stage_id"],
    "graph_groupbys": ["date_last_stage_update:month", "stage_id"],
}

groupby_assigned_time_and_prio = {
    "group_by": ["date_assign:month", "priority"],
    "graph_groupbys": ["date_assign:month", "priority"],
}

groupby_assigned_agent_and_prio = {
    "group_by": ["user_ids", "priority"],
    "graph_groupbys": ["user_ids", "priority"],
}

groupby_ticket_rot = {
    "group_by": ["date_assign:month", "user_ids"],
    "graph_groupbys": ["user_ids", "priority"],
}

help_domain = [
    ["project_id", "=", help_project],
    ["stage_id", "not ilike", "Cancelled"],
    ["create_date", "&gt;", "2020-01-01 00:00:00"],
]

################################################################
###################     components   ###########################
################################################################
DASHBOARD = """
<form string="My Dashboard">
    <board style="1-1">
        {column1}
        {column2}
        <column></column> <!-- unused column -->
    </board>
</form>
"""

COLUMN = """
<column>
    {slot}
</column>
"""

_GRAPH_ACTIONS = """
<action
    context="{context}"
    domain="%s"
    name="333" string="%s" view_mode="graph" modifiers="{{}}" id="%s">
</action>
"""


def graph_grouping(groupby):
    grouped_context = help_context.copy()
    grouped_context.update(groupby)
    return _GRAPH_ACTIONS.format(context=grouped_context)


def tags_domain_builder(tags):
    tags_domain = [["tag_ids", "ilike", t] for t in tags]
    ORs = ["|"] * (len(tags_domain) - 1)
    return ORs + tags_domain


SQUAD_X_UNASSIGNED = graph_grouping(groupby_stage_update_and_create)
# print(SQUAD_X_UNASSIGNED % ("WIP domain", "mon petit nom", "id_random"))


def x_unassigned(stage="tech", squad_name=None, tags=None, title=None):
    domain = help_domain.copy()
    name = "unassigned tickets"
    if stage:
        domain.append(["stage_id", "ilike", stage])
        name = f"{stage} unassigned tickets (week)"
    if squad_name:
        tag = f"tech_squad_{squad_name}"
        domain.append(("tag_ids", "ilike", tag))
        name = f"{squad_name} unassigned tickets (week)"
    if tags:
        domain += tags_domain_builder(tags)
        name = f"unassigned {'-'.join(tags)} tickets (week)"
    # keep just unassigned tickets
    domain.append(("user_ids", "=", False))
    if title:
        name = title
    return SQUAD_X_UNASSIGNED % (domain, name, uuid_gen())


SQUAD_X_PER_MONTH = graph_grouping(groupby_stage_update_and_stage)
# print(SQUAD_X_PER_MONTH)


def x_processed(squad_name=None, tags=None, title=None):
    domain = help_domain.copy()
    name = "Tickets processed per month"
    if squad_name:
        name = f"{squad_name} tickets processed per month"
        tag = f"tech_squad_{squad_name}"
        domain.append(["tag_ids", "ilike", tag])
    if tags:
        name = f"{'-'.join(tags)} tickets processed per month"
        domain += tags_domain_builder(tags)
    # selecting only the processed ticket
    domain += [
        "|",
        ["stage_id", "ilike", "cust. feedback"],
        ["stage_id", "ilike", "Done"],
    ]
    if title:
        name = title
    return SQUAD_X_PER_MONTH % (domain, name, uuid_gen())


def x_new(squad_name=None, tags=None, title=None):
    domain = help_domain.copy()
    name = "New tickets per month"
    if squad_name:
        name = f"New {squad_name} tickets per month"
        tag = f"tech_squad_{squad_name}"
        domain.append(["tag_ids", "ilike", tag])
    if tags:
        name = f"new {'-'.join(tags)} tickets per month"
        domain += tags_domain_builder(tags)
    if title:
        name = title
    return SQUAD_X_PER_MONTH % (domain, name, uuid_gen())


AGENT_PROCESSED_PER_MONTH = graph_grouping(groupby_assigned_time_and_prio)
# print(AGENT_PROCESSED_PER_MONTH)


def x_agent(trigram):
    domain = help_domain.copy()
    name = f"{trigram} - tickets per month"
    domain.append(["user_ids.login", "=", f"{trigram}@odoo.com"])
    return AGENT_PROCESSED_PER_MONTH % (domain, name, uuid_gen())


SQUAD_X_IN_TECH_PER_AGENT = graph_grouping(groupby_assigned_agent_and_prio)


def x_in_tech_per_agent(squad_name):
    leader_id = squad_to_leader_employee[squad_name]
    domain = help_domain.copy()
    domain += [
        "&amp;",
        ["stage_id", "ilike", "tech"],
        "|",
        ["user_ids.employee_id.parent_id.id", "=", leader_id],
        ["user_ids.employee_id.id", "=", leader_id],
    ]
    name = f"{squad_name}: in tech, per assigned"
    return SQUAD_X_IN_TECH_PER_AGENT % (domain, name, uuid_gen())


SQUAD_X_TICKET_ROT = graph_grouping(groupby_ticket_rot)


def x_rot(squad_name):
    leader_id = squad_to_leader_employee[squad_name]
    domain = help_domain.copy()
    domain += [
        "&amp;",
        ["stage_id", "ilike", "tech"],
        "|",
        ["user_ids.employee_id.parent_id.id", "=", leader_id],
        ["user_ids.employee_id.id", "=", leader_id],
    ]
    name = f"{squad_name}: ticket rot"
    return SQUAD_X_TICKET_ROT % (domain, name, uuid_gen())


################################################################
###################     generator    ###########################
################################################################


def squad_helper(squad_name, *functions):
    return [f(squad_name=squad_name) for f in functions]


def tags_helper(tags, *functions):
    return [f(tags=tags) for f in functions]


def x_agent_helper(trigrams):
    return [x_agent(trigram) for trigram in trigrams]


def my_generator(main_squad):
    top = [
        [
            x_unassigned(squad_name=main_squad),
            x_processed(squad_name=main_squad),
            x_new(squad_name=main_squad),
        ],
        [
            x_in_tech_per_agent(squad_name=main_squad),
            x_rot(squad_name=main_squad),
        ],
    ]
    the_rest = [
        [
            *tags_helper(["Technical"], x_unassigned, x_new, x_processed),
            # x_unassigned(stage=None),
            *squad_helper(None, x_new, x_processed),
            *x_agent_helper(get_from_squad(main_squad)),
        ],
        [
            """
            <action
                context="{'lang': 'en_US', 'tz': 'Europe/Brussels', 'uid': 963957, 'allowed_company_ids': [1, 2, 3, 4, 5, 14, 17], 'group_by': ['company_id'], 'orderedBy': [], 'dashboard_merge_domains_contexts': False}"
                domain="['&amp;', ['share', '=', False], '|', ['employee_id.department_id.id', '=', 153], '|', '|','|', ['employee_id.parent_id.parent_id.parent_id.id', '=', 1313226], ['employee_id.parent_id.parent_id.id', '=', 1313226], ['employee_id.parent_id.id', '=', 1313226], ['employee_id.id', '=', 1313226]]" name="17"
                string="Tech Support Team" view_mode="list" modifiers="{}" id="action_1_2"></action>
            """,  # not everyone in tech BE is in the right departement, filtering on the manager hierachy (with some future proofing)
            """
            <action
                context="{'lang': 'en_US', 'tz': 'Europe/Brussels', 'uid': 963957, 'allowed_company_ids': [1, 2, 3, 4, 5, 14, 17], 'group_by': ['company_id'], 'orderedBy': [], 'dashboard_merge_domains_contexts': False}"
                domain="['&amp;', ['share', '=', False], ['employee_id.department_id.id', '=', 152]]" name="17"
                string="Functionnal Support Team" view_mode="list" modifiers="{}" id="action_1_3"></action>
            """,
            """
            <action
                context="{'lang': 'en_US', 'tz': 'Europe/Brussels', 'uid': 963957, 'allowed_company_ids': [1, 2, 3, 4, 5, 14, 17], 'group_by': ['company_id'], 'orderedBy': [], 'dashboard_merge_domains_contexts': False}"
                domain="['&amp;', ['share', '=', False], ['employee_id.department_id.id', '=', 164]]" name="17"
                string="Bugfix Team" view_mode="list" modifiers="{}" id="action_1_4"></action>
            """,
            """
            <action
                context="{'lang': 'en_GB', 'tz': 'Europe/Brussels', 'uid': 963957, 'allowed_company_ids': [1], 'active_model': 'project.project', 'active_id': 250, 'active_ids': [250], 'pivot_row_groupby': ['user_ids'], 'default_project_id': 250, 'group_by': ['write_date:month'], 'orderedBy': [], 'dashboard_merge_domains_contexts': False}"
                domain="['&amp;', ['project_id', '=', 250], '&amp;', ['project_id', '=', 250], ['message_is_follower', '=', True]]"
                name="333" string="RD VALUE DEVs I follow" view_mode="kanban" modifiers="{}" id="action_1_5" fold="1">
            </action>
            """,
            *[
                card
                for squad_name in squad_to_leader_employee
                if squad_name != main_squad
                for card in squad_helper(
                    squad_name,
                    x_unassigned,
                    x_new,
                    x_processed,
                    x_in_tech_per_agent,
                    x_rot,
                )
            ],
            *squad_helper("sh", x_unassigned, x_new, x_processed),
            *squad_helper("infra", x_unassigned, x_new, x_processed),
            *tags_helper(["saas-ops"], x_unassigned, x_new, x_processed),
            *tags_helper(["apps"], x_unassigned, x_new, x_processed),
            *x_agent_helper(get_from_squad(main_squad, not_in=True)),
        ],
    ]
    components = []
    for col_top, col_bot in zip(top, the_rest):
        components.append(col_top + col_bot)

    col1 = COLUMN.format(slot="".join(components[0]))
    col2 = COLUMN.format(slot="".join(components[1]))
    dash = DASHBOARD.format(column1=col1, column2=col2)
    print(dash)


if __name__ == "__main__":
    print(
        "What's your squad ? [v]aria / [a]ccount / [po]s / [st]ock / [sm] / [pe]rf / [w]ebsite_js / [o]ther"
    )
    pick = input()
    pic_match = {
        "v": "varia",
        "a": "account",
        "po": "pos",
        "st": "stock",
        "sm": "sm",
        "pe": "perf",
        "w": "website_js",
        "o": "other",
    }
    my_generator(pic_match[pick])
    # TODO
    # dynamically generate agents (varia, not_varia) list
    # automatically backup the current dashboard on odoo.com
    # automaticlaly push the newly generated dashboard to odoo.com
