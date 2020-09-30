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

from utils import env

# relevant_saas_versions = ["12.3"]
# RELEVANT_BRANCHES = [f"saas-{s}" for s in relevant_saas_versions]
# RELEVANT_BRANCHES += ["12.0", "13.0", "14.0"]

# optimize for smaller checkout between versions on git_odoo pull --all
RELEVANT_BRANCHES = [
    "12.0",
    "saas-12.3",
    "13.0",
    "14.0",
]

VERSIONED_REPOS = [env.ODOO, env.ENTERPRISE, env.DESIGN_THEMES, env.USER_DOC]
SINGLE_VERSION_REPOS = [env.INTERNAL, env.PAAS]
SUPPORT_REPOS = [env.ST]
ALL_REPOS = VERSIONED_REPOS + SINGLE_VERSION_REPOS + SUPPORT_REPOS


def _repos(repos_names):
    """ Generator of repo objects for repos_names repos.
    """
    for rn in repos_names:
        # assuming repos_names is either a list of full paths
        # or folders in ~/src
        if "/" not in rn:
            rn = f"{env.SRC}/{rn}"
        yield git.Repo(rn)


def _try_for_all_remotes(
    repo,
    F,
    *fargs,
    raise_on_exception=True,
    stop_on_success=True,
    verbose=False,
    **fkwargs,
):
    # execute the function :F on all remotes, until one succeeds
    # the remote is give to :F as a keyword argument, with the key `remote` added.
    # if :raise_on_exception is True and none of the remotes succeeded,
    # the first git error is reraised. If :raise_on_exception is False,
    # the git errors are simply printed.
    # if :stop_on_success is True, the process stops as soon as a succesful
    # execution of :F happens.
    remotes = [repo.remotes.origin] + [
        rem for rem in repo.remotes if rem != repo.remotes.origin
    ]
    # storing all errors to help debugging
    git_errors = []
    res = []
    for remote in remotes:
        if verbose:
            print(f"remote: {remote}")
        fkwargs["remote"] = remote
        try:
            res += [F(*fargs, **fkwargs)]
        except git.exc.GitCommandError as ge:
            git_errors.append(ge)
            if not stop_on_success:
                print(f"Error : {ge}")
                print("------------------")
        else:
            if stop_on_success:
                break
    else:
        if raise_on_exception:
            raise git_errors[0]
        elif git_errors and stop_on_success:
            print(f"Error : {git_errors[0]}")
            print("------------------")
    return res


def shorten_path(path):
    # return just the last bit of the path
    return path.split("/")[-1]


class DetachedHeadError(Exception):
    pass


class TooManyVersions(Exception):
    pass


def _nbr_commits_ahead_and_behind(repo):
    try:
        branch_name = repo.active_branch.name
    except TypeError as e:
        if str(e).startswith("HEAD is a detached symbolic reference"):
            raise DetachedHeadError
        raise

    def count_commits(remote_name="origin", ahead=True):
        s = "{remote}/{branch}..{branch}" if ahead else "{branch}..{remote}/{branch}"
        s = s.format(remote=remote_name, branch=branch_name)
        # HACK: getting the length of a generator
        nbr_commit = sum(1 for _ in repo.iter_commits(s))
        return nbr_commit

    def commits_aheads_and_behind(*args, **kwargs):
        nbr_commit_ahead = count_commits(remote_name=kwargs["remote"].name, ahead=True)
        nbr_commit_behind = count_commits(
            remote_name=kwargs["remote"].name, ahead=False
        )
        return (nbr_commit_ahead, nbr_commit_behind)

    return _try_for_all_remotes(repo, commits_aheads_and_behind)[0]


def list_all_repos_info():
    """ display the available information regarding the community, enterprise,
    design themes, internal, paas and support-tools current branch
    """
    repos = ALL_REPOS
    for repo_name, repo in zip(repos, _repos(repos)):
        repo_name = shorten_path(repo_name)
        print(repo_name)
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
            print("  !!! With unstaged changes !!!")
        if repo.index.diff("HEAD"):
            print("  !!! With uncommited changes !!!")


def fetch_all_repos_info():
    """ updates the available information regarding the community, enterprise,
    design themes, internal, paas and support-tools repos
    """

    def fetch(*args, **kwargs):
        kwargs["remote"].fetch()

    repos = ALL_REPOS
    for repo_name, repo in zip(repos, _repos(repos)):
        repo_name = shorten_path(repo_name)
        print(f"fetching {repo_name}")
        _try_for_all_remotes(
            repo, fetch, raise_on_exception=False, stop_on_success=False, verbose=True
        )


def odoo_repos_pull(version=None, fast=False):
    """ Updates branches of the community, enterprise and design themes repos.
    If no version is provided, update the current branche.
    If :version is not a string, itterate on it and update the given branches sequentially.
    """
    if version and isinstance(version, list):
        for v in version:
            odoo_repos_pull(v, fast)
            fast = True  # only pull internal and paas once
        return
    failed_checkouts = []
    if version:
        failed_checkouts = odoo_repos_checkout([version])
    repos = VERSIONED_REPOS[:]
    if not fast:
        repos += SINGLE_VERSION_REPOS
    if failed_checkouts:
        for fc in failed_checkouts:
            repos.remove(fc)

    def pull(*args, **kwargs):
        kwargs["remote"].pull()

    for repo_name, repo in zip(repos, _repos(repos)):
        repo_name = shorten_path(repo_name)
        print(f"Pulling {repo_name}")
        _try_for_all_remotes(repo, pull, raise_on_exception=False)


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


def odoo_repos_checkout(versions):
    """ checkout to the :versions branche of the community, enterprise and design themes repos.
    If only one version is given, uses it for odoo, enterprise and design-themes
    If mutliple versions are given, uses them in the order odoo, enterprise, design-themes, internal
        If the number of versions is greater than the number of handled repos, the remaining version
        are ignored (but a warning is shown)
    returns a list of the repos for which the checkout failed
    """
    if len(versions) > 1:
        odoo_repos_checkout_multi(versions)
        return
    else:
        version = versions[0]
    # 1 version given, use it for the main standard odoo repos
    repos = VERSIONED_REPOS[:]
    if version == "8.0":
        repos.remove(env.ENTERPRISE)
    failed_checkouts = []
    for repo_path, repo in zip(repos, _repos(repos)):
        repo_name = shorten_path(repo_path)
        print(f"checkouting {repo_name} to {version}")
        try:
            _stash_and_checkout(repo, version)
        except git.exc.GitCommandError as err:
            print(f'Could not checkout repo "{repo_name}" to version "{version}"')
            print("Failed with the following error:")
            print(err)
            failed_checkouts.append(repo_path)
    return failed_checkouts


def odoo_repos_checkout_multi(versions, raise_on_error=False):
    repos = [env.ODOO, env.ENTERPRISE, env.DESIGN_THEMES, env.INTERNAL]
    if len(versions) > len(repos):
        if raise_on_error:
            raise TooManyVersions(
                f"There are too many version given ({len(versions)}). Maximum is {len(repos)}."
            )
        print(f"too many params, ignoring the following {versions[len(repos):]}")
    for version, repo_name, repo in zip(versions, repos, _repos(repos)):
        repo_name = shorten_path(repo_name)
        print(f"checkouting {repo_name} to {version}")
        _stash_and_checkout(repo, version)


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
