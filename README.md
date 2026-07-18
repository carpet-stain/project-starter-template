# project-starter-template

Copier toolkit for scaffolding governed GitHub repos: a language-agnostic
git-flow governance base, plus language overlays layered on top (currently
`python/`). This repo _is_ the base — it's bootstrapped from its own
`git-flow` template (dogfood: the repo that ships the base is itself
governed by it).

## Install

```sh
git clone https://github.com/carpet-stain/project-starter-template.git
```

`uvx` (from [`uv`](https://docs.astral.sh/uv/)) runs `copier` and this
repo's own tooling (`scripts/lint-templates.sh`) without a separate
install.

## Use

Scaffold a new repo with the base alone:

```sh
uvx copier copy project-starter-template/git-flow <new-project-dir>
```

Or layer a language overlay on top — apply the base first, then the
overlay, into the same directory:

```sh
uvx copier copy project-starter-template/git-flow <new-project-dir>
uvx copier copy project-starter-template/python <new-project-dir>
```

Each template's own README (`git-flow/README.md`, `python/README.md`)
covers its questions, what it produces, and the full bootstrap runbook
(labels, branch protection, the `RELEASE_PAT` secret) — this file is a
pointer, not a restatement. A generated repo carries no
`.copier-answers` file and has no `copier update` path: scaffold once,
then evolve the repo directly — see `docs/adr/` for the decision and why.

Repo creation, the canonical label set, and branch protection for every
repo scaffolded from this base — including this one — are managed via
`carpet-stain/infra`'s `repos.tf`, not a manual bootstrap step; see that
repo for the governance side of the story.

## Verifying template changes

`just lint` runs this repo's own source checks; `just lint-templates`
render-then-lints the copier templates themselves (`scripts/lint-templates.sh`
has the strategy) — CI runs both.

## Contributing

The contributor guide — workflow, commit rules, tooling, credentials — lives in
`AGENTS.md` (composed from your agent-config rules; generate it if it isn't
present yet). Architecture decisions live in
[`docs/adr/`](docs/adr/README.md). This README is the human front door and
points at those homes rather than restating them.
