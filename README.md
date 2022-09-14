# Get LFS statistics for a GitHub organization

## Usage

1. `git clone https://github.com/reposaurus/org-lfs-report && cd org-lfs-report`
2. `gem install bundler`
3. `script/bootstrap`
4. `script/stats [ORG_NAME]`

## How it works

It uses [Octokit.rb](https://github.com/octokit/octokit.rb) to fetch a list of your organization's repositories (public or public and private), and [git](https://git-scm.com) and [git-lfs](https://git-lfs.github.com/) to gather LFS statistics.

## Example output for @reposaurus

```
TBD
```

## Batching repository cloning

This tool will clone 5 repositories at a time by default and remove those 5 before
cloning and counting the next batch, but you can set a custom batch size by setting
the environment variable `BATCH_SIZE` to a non-zero number.

CAUTION: If you have a lot of repositories in your organization, or some of them
are very large, setting a large batch size will mean that your disk could fill up
before the tool finishes running and you get a chance to remove the cloned repositories
manually.

## Counting private repositories

To look at private repositories, you'll need to pass a [personal access token](https://github.com/settings/tokens/new) with `repo` scope as `GITHUB_TOKEN`. You can do this by adding `GITHUB_TOKEN=[TOKEN]` to a `.env` file in the repository's root.

If you are working with GitHub Enterprise and want to change your URL, simply add `GITHUB_ENTERPRISE_URL=https://<ghe-url>/api/v3` to the `.env` file


Sample `.env` File :

```bash
GITHUB_TOKEN="<token>"
GITHUB_ENTERPRISE_URL="https://my-ghe.local/api/v3"
```
