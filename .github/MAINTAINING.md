# Repository settings

These files describe repository settings. Committing them does **not** activate
the settings in GitHub.

## Apply with GitHub CLI

With Python 3.10+ and an authenticated GitHub CLI account that administers the
repository:

```sh
python3 scripts/configure-repository.py --repo Lauritz-Timm/matugen-nvim-bridge --dry-run
python3 scripts/configure-repository.py --repo Lauritz-Timm/matugen-nvim-bridge
```

The script checks that the required CI jobs passed on the current default branch
before applying settings. Repeated runs update the rulesets by name.
Its preflight and update behavior can be checked with
`python3 tests/repository.py`.

## Apply in GitHub

In **Settings > Rules > Rulesets**, choose **New ruleset > Import a ruleset**.
Import and create both [main.json](rulesets/main.json) and
[releases.json](rulesets/releases.json), with enforcement set to **Active**.

The main ruleset requires pull requests, all four CI checks from GitHub Actions,
an up-to-date branch, resolved conversations and linear history. Force pushes
and deletion are blocked. No actor has a standing bypass.

Required approvals are zero so a sole maintainer can merge their own passing
pull request. Code owner review is optional. Raise the approval count when
another maintainer can review changes.

The release ruleset prevents changing or deleting existing `v*` tags. Creating
a new version tag remains allowed.

In **Settings > General**, enable squash merging, disable merge commits and
rebase merging, and enable automatic deletion of merged branches. The complete
settings payload is [repository.json](repository.json).

In **Settings > Actions > General**, select read-only workflow permissions and
leave permission to approve pull requests disabled. The payload is
[actions-permissions.json](actions-permissions.json). Individual CI workflows
also declare read-only permissions.

## Routine changes

Create a branch and open a pull request. Wait for every CI job and resolve review
threads before squash merging. The four required check names must stay aligned
with `workflows/ci.yml`.

GitHub Actions dependencies are pinned to commit SHAs and checked monthly by
Dependabot. Review updates through the same pull request process.

For a release, update the changelog, run the full suite, merge the pull request,
then create a new version tag. Existing version tags are immutable after the
release ruleset is activated.

References: [ruleset import](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/managing-rulesets-for-a-repository),
[ruleset API](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset).
