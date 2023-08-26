#!/usr/bin/env python3
"""
git_watcher

usage:
    git_watcher
    git_watcher initialize
    git_watcher add <path>

"""

import sys
import os
import subprocess
import json

config_path = os.path.expanduser("~/.config/git_watcher/config.json")
watchers_config_path = os.path.expanduser("~/.config/git_watcher/watchers.json")
default_config = {
    'output_folder': "~/Desktop/",
}
default_watcher_config = {
    "base": {
        "path": "~/odoo/versions/master/odoo/odoo/addons/base",
        "URL": 'https://github.com/odoo/odoo/',
        "known_commits": [],
    }
}

def app_setup():
    os.makedirs(os.path.dirname(config_path), exist_ok=True)
    with open(config_path, 'w') as conf:
        json.dump(default_config, conf, indent=4)
    with open(watchers_config_path, 'w') as watchers:
        json.dump(default_watcher_config, watchers, indent=4)

def add_watcher(path):
    cmd = f"git -C {path} remote get-url origin".split()
    git_repo_url = subprocess.run(cmd, capture_output=True).stdout.decode("utf-8").strip()
    web_repo_url = git_repo_url.replace(":", "/").replace("git@", "https://").replace(".git", "/")
    with open(watchers_config_path) as f_watchers:
        watchers = json.load(f_watchers)
    watchers[path] = {
        "path": path,
        "URL": web_repo_url,
        "known_commits": [],
    }
    with open(watchers_config_path, 'w') as f_watchers:
        json.dump(watchers, f_watchers, indent=4)

def app_run_check():
    raise NotImplementedError("not finished yet")

if __name__ == "__main__":
    if "--help" in sys.argv:
        print(__doc__)
        sys.exit(0)
    if len(sys.argv) == 1:
        app_run_check()
    elif sys.argv[1] == 'initialize':
        app_setup()
    elif sys.argv[1] == 'add':
        new_path = sys.argv[2]
        add_watcher(new_path)
    else:
        print("incorrect usage, seek --help")
        sys.exit(1)
