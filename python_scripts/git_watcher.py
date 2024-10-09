#!/usr/bin/env python3
"""
git_watcher

usage:
    git_watcher
    git_watcher initialize
    git_watcher add <path>
    git_watcher list
    git_watcher remove <name>


    Usage note:  In it's current state this tool is meant to be used with repos that don't change their versions all the time.
    With a multiverse set up for example, it should work quite well.
    It can work with a set up that changes its branch at a given path, you will just get garbage data when not in the 'right' branch,
    but should work fine once the correct branch is checked out again  (just random useless data will be stored, which shouldn't really be an issue)
    This does NOT update the branches by itself (for now ?)

    future improvement:
        - version the watchers and config file to allow automated migration to future versions of git_watcher automnatically (if the data strucuture is changed)
        - [KNOWN BUG] if the last section of the path of new watcher matches the name of an exisitng watcher, it will override it.
        - make git_watcher version specific for each watcher and independante of the currently checked out branche
        - optionally autofetch the new commits (not pulling the branch to get them , just fecth origin/xxxx  to not potentially break local changes)
"""

import hashlib
import html
import json
import os
import subprocess
import sys

# const ------------------------------------------------------------------------------------------

config_path = os.path.expanduser("~/.config/git_watcher/config.json")
watchers_config_path = os.path.expanduser("~/.config/git_watcher/watchers.json")
default_config = {
    "output_folder": "~/Desktop/",
}
default_watcher_config = {
    "example": {
        "path": "~/odoo/versions/master/odoo/odoo/addons/base",
        "URL": "https://github.com/odoo/odoo/",
        "known_commits": [],
    }
}


# helpers  --------------------------------------------------------------------------------------------


def _get_expected_file(what):
    try:
        with open(what) as f_what:
            return json.load(f_what)
    except FileNotFoundError:
        print("the tool was not setup yet, run `git_watcher initialize`")
        print(
            "then check the --help (and probably the code too, because i'm note going to write a proper doc for this)"
        )
        sys.exit(1)


def _get_config():
    return _get_expected_file(config_path)


def _get_data_old():
    return _get_expected_file(watchers_config_path)


def _save_new_data(data):
    with open(watchers_config_path, "w") as f_watchers:
        json.dump(data, f_watchers, indent=4)


def _path_to_first_parent_dir(path):
    if os.path.isfile(path):
        path = os.path.dirname(path)
    return path


# html builder  ---------------------------------------------------------------------------------------

# js and css stolen from https://www.w3schools.com/howto/howto_js_collapsible.asp
css = """
.collapsible {
    background-color: #777;
    color: white;
    cursor: pointer;
    padding: 18px;
    width: 100%;
    border: none;
    text-align: left;
    outline: none;
    font-size: 15px;
}

.active, .collapsible:hover {
    background-color: #555;
}

.content {
    padding: 0 18px;
    display: block;
    overflow: hidden;
    background-color: #f1f1f1;
}
"""
js = """
var coll = document.getElementsByClassName("collapsible");
var i;

for (i = 0; i < coll.length; i++) {
    coll[i].addEventListener("click", function() {
        this.classList.toggle("active");
        var content = this.nextElementSibling;
        content.style.display = content.style.display === "block" ? "none" : "block";
    });
}
"""

page = """
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>{title}</title>
    <style>
        {css}
    </style>
  </head>
  <body>
        {body}
  </body>
  <script>
        {js}
  </script>
</html>
"""

collapsible = """
<button type="button" class="collapsible">{title}</button>
<div class="content">
  {content}
</div>
"""


def _link(url, text):
    return '<a href="%s" target="_blank">%s</a>' % (url, html.escape(text))


def _one_watcher(name, new_commits, repo):
    ul = "<ul>%s</ul>" % "\n".join(
        "<li>%s</li>" % _link(repo + "commit/" + commit[0], commit[1]) for commit in new_commits
    )
    if not new_commits:
        ul = "<p>Nothing new over here</p>"
    return collapsible.format(title=name, content=ul)


def _build_html_report(watchers, new_commits):
    body = "\n".join(_one_watcher(name, commits, watchers[name]["URL"]) for name, commits in new_commits.items())
    return page.format(title="git_watcher report", css=css, js=js, body=body)


# main actions  ----------------------------------------------------------------------------------------


def app_setup():
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, "w") as conf:
        json.dump(default_config, conf, indent=4)
    with open(watchers_config_path, "w") as watchers:
        json.dump(default_watcher_config, watchers, indent=4)


def add_watcher(path):
    dir_path = _path_to_first_parent_dir(path)
    cmd = f"git -C {dir_path} remote get-url origin".split()
    git_repo_url = subprocess.run(cmd, capture_output=True, check=True).stdout.decode("utf-8").strip()
    web_repo_url = git_repo_url.replace(":", "/").replace("git@", "https://").replace(".git", "/")
    watchers = _get_data_old()
    name = path.split("/")[-1]
    watchers[name] = {
        "path": path,
        "URL": web_repo_url,
        "known_commits": [],
    }
    _save_new_data(watchers)


def list_watchers():
    watchers = _get_data_old()
    for name, w_info in watchers.items():
        print(name, ":")
        print("\t", "path :", w_info["path"])
        print("\t", "repo :", w_info["URL"])
        print("\t", "# known commits :", len(w_info["known_commits"]))


def remove_watcher(name):
    watchers = _get_data_old()
    try:
        del watchers[name]
    except KeyError:
        print(f"watcher {name} does not exist, nothing was done")
    else:
        _save_new_data(watchers)


def app_run_check():
    # get old data
    watchers = _get_data_old()
    # get the new commits
    report = dict()
    for name, w_info in watchers.items():
        print("processing :", name)
        report[name] = []
        path, _, known_commits = (
            w_info["path"],
            w_info["URL"],
            set(w_info["known_commits"]),
        )
        path = os.path.expanduser(path)
        dir_path = _path_to_first_parent_dir(path)
        cmd = ["git", "-C", dir_path, "log", "--pretty=format:%h!|!%s", path]
        git_log = subprocess.run(cmd, capture_output=True, check=True).stdout.decode("utf-8").strip()
        for log_line in (line for line in git_log.split("\n") if line):
            commit, title = log_line.split("!|!", maxsplit=1)
            if commit not in known_commits:
                report[name].append((commit, title))
                watchers[name]["known_commits"].append(commit)
    if sum(len(new_commits) for new_commits in report.values()) == 0:
        print("----------------   nothing new since last report  ------------------")
        return
    # create html report
    html = _build_html_report(watchers, report)
    report_name = "git_watcher_report_%s.html" % hashlib.md5(html.encode("utf-8")).hexdigest()
    report_path = os.path.expanduser(_get_config()["output_folder"]) + report_name
    with open(report_path, "w") as f_report:
        f_report.write(html)
    print(f"You can find the report at {report_path}")
    # save data for next time
    _save_new_data(watchers)


if __name__ == "__main__":
    if "--help" in sys.argv:
        print(__doc__)
        sys.exit(0)
    if len(sys.argv) == 1:
        app_run_check()
    elif sys.argv[1] == "initialize":
        app_setup()
    elif sys.argv[1] == "add":
        new_path = sys.argv[2]
        add_watcher(new_path)
    elif sys.argv[1] == "list":
        list_watchers()
    elif sys.argv[1] == "remove":
        name = sys.argv[2]
        remove_watcher(name)
    else:
        print("incorrect usage, seek --help")
        sys.exit(1)
