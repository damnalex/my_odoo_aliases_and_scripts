#!/usr/bin/env python3
"""
git_odoo

usage:
    git_odoo checkout (<version> | --dbname <dbname>)
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

relevant_saas_versions = ["13", "14", "15", "11.1", "11.2", "11.3", "11.4", "12.3"]
RELEVANT_BRANCHES = ["saas-%s" % s for s in relevant_saas_versions]
RELEVANT_BRANCHES += ["10.0", "11.0", "13.0", "12.0"]


def _repos(repos_names):
    """ returns a generator listing the repos of repos_names
    """
    repos_paths = ("~/src/%s" % r for r in repos_names)
    return (git.Repo(rp) for rp in repos_paths)


def _nbr_commits_ahead_and_behind(repo):
    branch_name = repo.active_branch.name

    def count_commits(repo, branch_name, remote_name="origin", ahead=True):
        s = "{remote}/{branch}..{branch}" if ahead else "{branch}..{remote}/{branch}"
        s = s.format(remote=remote_name, branch=branch_name)
        # HACK: getting the length of a generator
        nbr_commit = sum(1 for _ in repo.iter_commits(s))
        return nbr_commit

    try:
        nbr_commit_ahead = count_commits(repo, branch_name, ahead=True)
        nbr_commit_behind = count_commits(repo, branch_name, ahead=False)
    except git.exc.GitCommandError as ge:
        # test all the remotes for this branch, return for the first one matching
        found_valide_remote = False
        for remote in repo.remotes:
            try:
                nbr_commit_ahead = count_commits(
                    repo, branch_name, remote_name=remote.name, ahead=True
                )
                nbr_commit_behind = count_commits(
                    repo, branch_name, remote_name=remote.name, ahead=False
                )
            except git.exc.GitCommandError:
                pass
            else:
                found_valide_remote = True
                break
        if not found_valide_remote:
            # did not find any remote matching, reraising original error
            raise ge

    return (nbr_commit_ahead, nbr_commit_behind)


def list_all_repos_info():
    """ display the available information regarding the community, enterprise,
    design themes, internal and support-tools current branch
    """
    repos = ["odoo", "enterprise", "design-themes", "internal", "support-tools"]
    for repo_name, repo in zip(repos, _repos(repos)):
        try:
            nbr_ahead, nbr_behind = _nbr_commits_ahead_and_behind(repo)
        except git.exc.GitCommandError:
            nbr_ahead, nbr_behind = "N/A", "N/A"
        print("current %s branch" % (repo_name))
        print("  %s\t\t↓ %s ↑ %s" % (repo.active_branch.name, nbr_behind, nbr_ahead))
        if repo.index.diff(None):
            print("  !!! With Local changes !!!")


def fetch_all_repos_info():
    """ updates the available information regarding the community, enterprise,
    design themes, internal and support-tools repos
    """
    repos = ["odoo", "enterprise", "design-themes", "internal", "support-tools"]
    for repo_name, repo in zip(repos, _repos(repos)):
        for remote in repo.remotes:
            print("Fetching %s: %s" % (repo_name, remote.name))
            remote.fetch()


def odoo_repos_pull(version=None):
    """ Updates branches of the community, enterprise and design themes repos.
    If no version is provided, update the current branche.
    If :version is not a string, itterate on it and update the given branches sequentially.
    """
    if version and not isinstance(version, str):
        for v in version:
            odoo_repos_pull(v)
        return
    if version:
        odoo_repos_checkout(version)
    repos = ["odoo", "enterprise", "design-themes"]
    for repo_name, repo in zip(repos, _repos(repos)):
        origin = repo.remotes.origin
        print("Pulling %s" % repo_name)
        origin.pull()


def _get_version_from_db(dbname):
    """ get the odoo version of the given DB
    """
    with psycopg2.connect("dbname='%s'" % dbname) as conn:
        with conn.cursor() as cr:
            query = "SELECT replace((regexp_matches(latest_version, '^\d+\.0|^saas~\d+\.\d+|saas~\d+'))[1], '~', '-') FROM ir_module_module WHERE name='base'"
            cr.execute(query)
            return cr.fetchone()[0]


def odoo_repos_checkout(version):
    """ checkout to the :version branche of the community, enterprise and design themes repos.
    """
    repos = ["odoo", "enterprise", "design-themes"]
    if version == "8.0":
        repos.remove("enterprise")
    for repo_name, repo in zip(repos, _repos(repos)):
        print("checkouting %s to %s" % (repo_name, version))
        repo.git.checkout(version)


def main():
    # args parsing
    opt = docopt(__doc__)

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
            version = _get_version_from_db(dbname)
        odoo_repos_checkout(version)
        return


if __name__ == "__main__":
    main()
