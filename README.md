# gion-action

GitHub Actions for [gion](https://github.com/baz-scm/gion): check out only the directories a job needs, list what a PR changed without a checkout, and read or push to other repos.

| Action | What it does |
| --- | --- |
| `baz-scm/gion-action` | Installs gion and puts it on `PATH`. Then use `gion` in any `run:` step. |
| `baz-scm/gion-action/checkout` | Sparse checkout of the commit under test. |
| `baz-scm/gion-action/changed` | Changed files of a PR or push, as outputs. |

Every action installs gion itself, so you don't need the setup action before the other two. Linux and macOS runners, x64 and ARM64.

## Check out one directory

```yaml
- uses: baz-scm/gion-action/checkout@v1
  with:
    paths: |
      services/api
      libs/common
```

You get those paths plus the files in their parent directories (root config, lockfiles), at `$GITHUB_SHA`. Leave `paths` and `projects` empty to get the whole tree. The workspace has a small `.git` snapshot, so `git status`, `git diff` and pre-commit work. There is no history: tools that need tags or `git log` (GoReleaser, changelog generators, `git describe`) still need `actions/checkout`.

| Input | Default | |
| --- | --- | --- |
| `repository` | this repo | `owner/repo` or a git URL |
| `ref` | `github.sha` for this repo, else the remote's HEAD | branch, tag or commit |
| `paths` | everything | one per line |
| `projects` | none | names from `.gion/projects.toml`, one per line; combines with `paths` |
| `path` | `.` | directory to put the workspace in |
| `git` | `true` | `false` skips the `.git` snapshot |
| `token` | `github.token` | see [Tokens](#tokens) |
| `version` | pinned, see [Versioning](#versioning) | gion release, e.g. `v0.3.1`, or `latest` |

Outputs: `path`, `gion-version`.

If the repo names projects in `.gion/projects.toml`, check one out by name. You get its paths plus their local dependencies:

```yaml
- uses: baz-scm/gion-action/checkout@v1
  with:
    projects: web
```

```toml
# .gion/projects.toml
[projects]
web = ["apps/web", "packages/ui"]
```

## Run jobs only when something changed

```yaml
- uses: baz-scm/gion-action/changed@v1
  id: changed
  with:
    paths: services/api
- if: steps.changed.outputs.any == 'true'
  run: make -C services/api test
```

Fan out a matrix over changed directories:

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      files: ${{ steps.changed.outputs.json }}
    steps:
      - uses: baz-scm/gion-action/changed@v1
        id: changed
  test:
    needs: changes
    if: needs.changes.outputs.files != '[]'
    strategy:
      matrix:
        file: ${{ fromJSON(needs.changes.outputs.files) }}
    ...
```

Which commits it compares:

| Event | Compares |
| --- | --- |
| `pull_request` (and `_review`, `_review_comment`) | GitHub's test merge commit with its first parent: exactly what the PR changes, even if the base branch moved on |
| `push` | `github.event.before` to `github.sha` (a new branch: its last commit) |
| `merge_group` | the queue's `base_sha` to `head_sha` |
| anything else | set `base` and `head` |

| Input | Default | |
| --- | --- | --- |
| `repository` | this repo | |
| `base`, `head` | from the event | any rev gion takes (`main`, a tag, a sha, `sha^1`) |
| `paths` | everything | only report changes under these, one per line |
| `token`, `version` | | as above |

Outputs: `files` (one per line), `json` (array), `count`, `any` (`true`/`false`), `base`, `head`.

## Anything else

```yaml
- uses: baz-scm/gion-action@v1
- run: gion cat my-org/shared-config HEAD:deploy/prod.yaml > prod.yaml
- run: gion grep "$GITHUB_REPOSITORY" 'TODO\(' --path src
```

Outputs: `version`, `path` (the binary).

Commit from CI (needs `permissions: contents: write`):

```yaml
- run: gion commit "$GITHUB_REPOSITORY" -m "bump version" --to main VERSION=./VERSION
  env:
    GIT_AUTHOR_NAME: ci-bot
    GIT_AUTHOR_EMAIL: ci-bot@users.noreply.github.com
```

The push is compare-and-swap. If someone else pushed changes to other files, gion builds on top of them. If they changed the same file, the step fails instead of overwriting it.

## Tokens

Every action exports `token` as `GITHUB_TOKEN` to later steps, so plain `gion` commands authenticate too. The default `github.token` only reaches the current repository. To read other private repos or push to them, pass a PAT or GitHub App token:

```yaml
- uses: baz-scm/gion-action@v1
  with:
    token: ${{ secrets.ORG_READ_TOKEN }}
```

Set `token: ""` to export nothing.

## Caching

You don't need `actions/cache`. gion fetches only the objects a command needs, so a fresh runner is fast already. On self-hosted runners the binary goes into the runner tool cache and `~/.gion` persists between jobs anyway.

## Versioning

Each release of this action defaults to one gion release, the one its tests ran against. Installing a known version skips the "which release is latest" lookup, so it's faster than `version: latest`.

After each gion release a maintainer runs [bump-gion](.github/workflows/bump-gion.yml), which makes it the default, runs the tests, tags the next `v1.x.y` and moves `v1` to it. So `@v1` follows new gion releases. Use `@v1.x.y` or a commit to stay on one gion, or set `version` yourself.
