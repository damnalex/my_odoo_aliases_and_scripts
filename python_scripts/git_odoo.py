#!/usr/bin/env python3
"""
git_odoo

usage:
    git_odoo checkout (<version>... | --dbname <dbname>)
    git_odoo pull [--version <version> | --all]
    git_odoo fetch
    git_odoo list

options:
    --dbname=<dbname>       name of the database to use to select the right version to checkout
    --version=<version>     version to pull or checkout to
    --all                   pull all relevant branches

"""
from docopt import docopt
import psycopg2
import git

# relevant_saas_versions = ["11.3", "12.3"]
# RELEVANT_BRANCHES = [f"saas-{s}" for s in relevant_saas_versions]
# RELEVANT_BRANCHES += ["11.0", "12.0", "13.0"]

# optimize for smaller checkout between versions on git_odoo pull --all
RELEVANT_BRANCHES = [
    "11.0",
    "saas-11.3",
    "12.0",
    "saas-12.3",
    "13.0",
]


def _repos(repos_names):
    """ Generator of repo objects for repos_names repos.
    """
    for rn in repos_names:
        # assuming repos_names is either a list of full paths
        # or folders in ~/src
        if "/" not in rn:
            rn = f"~/src/{rn}"
        yield git.Repo(rn)


class DetachedHeadError(Exception):
    pass


def _nbr_commits_ahead_and_behind(repo):
    try:
        branch_name = repo.active_branch.name
    except TypeError as e:
        if str(e).startswith("HEAD is a detached symbolic reference"):
            raise DetachedHeadError
        raise

    def count_commits(repo, branch_name, remote_name="origin", ahead=True):
        s = "{remote}/{branch}..{branch}" if ahead else "{branch}..{remote}/{branch}"
        s = s.format(remote=remote_name, branch=branch_name)
        # HACK: getting the length of a generator
        nbr_commit = sum(1 for _ in repo.iter_commits(s))
        return nbr_commit

    git_error = []
    remotes_names = ["origin"] + [
        rem.name for rem in repo.remotes if rem.name != "origin"
    ]
    # test all the remotes for this branch (starting with origin),
    # break for the first one matching
    for remote_name in remotes_names:
        try:
            nbr_commit_ahead = count_commits(repo, branch_name, remote_name, ahead=True)
            nbr_commit_behind = count_commits(
                repo, branch_name, remote_name, ahead=False
            )
        except git.exc.GitCommandError as ge:
            git_error.append(ge)
        else:
            break
    else:
        # did not find any remote matching, reraising original error
        raise git_error[0]

    return (nbr_commit_ahead, nbr_commit_behind)


def list_all_repos_info():
    """ display the available information regarding the community, enterprise,
    design themes, internal and support-tools current branch
    """
    repos = ["odoo", "enterprise", "design-themes", "internal", "paas", "support-tools"]
    for repo_name, repo in zip(repos, _repos(repos)):
        print(f"current {repo_name} branch")
        try:
            nbr_ahead, nbr_behind = _nbr_commits_ahead_and_behind(repo)
        except git.exc.GitCommandError:
            print(f"  {repo.active_branch.name}")
        except DetachedHeadError:
            print(f"  HEAD --> {repo.head.commit}")
        else:
            nb_tabul = 3 if len(repo.active_branch.name) < 6 else 2
            tabuls = "\t" * nb_tabul
            print(f"  {repo.active_branch.name}{tabuls}↓ {nbr_behind} ↑ {nbr_ahead}")
        if repo.index.diff(None):
            print("  !!! With Local changes !!!")


def fetch_all_repos_info():
    """ updates the available information regarding the community, enterprise,
    design themes, internal and support-tools repos
    """
    repos = ["odoo", "enterprise", "design-themes", "internal", "paas", "support-tools"]
    for repo_name, repo in zip(repos, _repos(repos)):
        for remote in repo.remotes:
            print(f"Fetching {repo_name}: {remote}")
            try:
                remote.fetch()
            except git.exc.GitCommandError as ge:
                print(f"Could not fetch from {remote}/{repo_name}")
                print(f"Error : {ge}")
                print("------------------")


def odoo_repos_pull(version=None, fast=False):
    """ Updates branches of the community, enterprise and design themes repos.
    If no version is provided, update the current branche.
    If :version is not a string, itterate on it and update the given branches sequentially.
    """
    if version and not isinstance(version, str):
        for v in version:
            odoo_repos_pull(v, fast)
            fast = True  # only pull internal and paas once
        return
    if version:
        odoo_repos_checkout([version])
    repos = ["odoo", "enterprise", "design-themes"]
    if not fast:
        repos += ["internal", "paas"]
    for repo_name, repo in zip(repos, _repos(repos)):
        print(f"Pulling {repo_name}")
        repo.git.stash()
        remotes = [repo.remotes.origin] + [
            rem for rem in repo.remotes if rem != repo.remotes.origin
        ]
        # test all the remotes for this branch (starting with origin),
        # break for the first one matching
        git_errors = []
        for remote in remotes:
            try:
                remote.pull()
            except git.exc.GitCommandError as ge:
                git_errors.append(ge)
            else:
                break
        else:
            # did not find any remote matching, showing original error
            print(f"Could not pull from repo {repo_name}")
            print(f"Error : {git_errors[0]}")
            print("------------------")


def _get_version_from_db(dbname):
    """ get the odoo version of the given DB
    """
    with psycopg2.connect(f"dbname='{dbname}'") as conn, conn.cursor() as cr:
        query = "SELECT replace((regexp_matches(latest_version, '^\d+\.0|^saas~\d+\.\d+|saas~\d+'))[1], '~', '-') FROM ir_module_module WHERE name='base'"
        cr.execute(query)
        return cr.fetchone()[0]


def _stash_and_checkout(repo, version):
    """ Stash checkout and clean a given repo
    """
    repo.git.stash()
    repo.git.checkout(version)
    repo.git.clean("-df")


def odoo_repos_checkout(version):
    """ checkout to the :version branche of the community, enterprise and design themes repos.
    """
    if len(version) > 1:
        odoo_repos_checkout_multi(version)
        return
    else:
        version = version[0]

    repos = ["odoo", "enterprise", "design-themes"]
    if version == "8.0":
        repos.remove("enterprise")
    for repo_name, repo in zip(repos, _repos(repos)):
        print(f"checkouting {repo_name} to {version}")
        _stash_and_checkout(repo, version)


def odoo_repos_checkout_multi(versions):
    repos = ["odoo", "enterprise", "design-themes", "internal"]
    for version, repo_name, repo in zip(versions, repos, _repos(repos)):
        print(f"checkouting {repo_name} to {version}")
        _stash_and_checkout(repo, version)
    if len(versions) > len(repos):
        print(f"too many params, ignoring the following {versions[len(repos):]}")


def App(**opt):
    # opt is a docopt style dict
    if opt.get("list"):
        list_all_repos_info()
        return

    if opt.get("fetch"):
        fetch_all_repos_info()
        return

    if opt.get("pull"):
        version = opt.get("--version")
        if opt.get("--all"):
            version = RELEVANT_BRANCHES
        odoo_repos_pull(version)
        return

    if opt.get("checkout"):
        version = opt.get("<version>")
        if not version:
            dbname = opt.get("--dbname")
            version = [_get_version_from_db(dbname)]
        odoo_repos_checkout(version)
        return


if __name__ == "__main__":
    # args parsing
    opt = docopt(__doc__)
    App(**opt)
