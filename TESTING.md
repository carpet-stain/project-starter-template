# Testing

This repo ships copier templates, so almost none of the code that matters
executes here — it executes in _rendered_ repos. Testing therefore centers on
rendering the templates and verifying the output behaves, not on unit-testing
the source. The layers below are ordered by cost and fidelity; CI runs the
first two on every PR, the rest are on-demand.

## 1. Static source checks — `just lint`

This repo's own lefthook pre-commit jobs (`lefthook.yml`) over the source
tree: the standard base slice (actionlint, markdown, yaml, gitleaks, shell,
editorconfig, comment-concision) plus four host-only jobs — `j2lint` (raw
jinja syntax; skips the known false-positive files, see
`scripts/lint-templates.sh`'s header), the vendored payload's `pr-review`
unit tests, pst's own `pr-review` copy's unit tests (#155 — the live
advisory reviewer running on this repo itself, distinct from the payload),
and `pst-sync`'s unit tests (#157 — the sync channel's extracted parsing/
validation/comparison logic; its I/O half is live-e2e only, layer 6 below).
CI split: `lint.yml` runs the base slice (`--tag base`); the four host-only
jobs are untagged and gate in `lint-templates.yml` instead — j2lint inside
the harness, both pr-review copies and pst-sync as their own dedicated steps.

Pre-push adds `check-governance-propagation.sh` (the both-sides-or-neither
root-vs-template advisory) and the PR itself gates on `pr-guards.yml` /
`adr-guard.yml` — governance, not template testing; pointers only.

Limits: this proves the _source_ parses and is clean. Jinja/copier syntax
breaks most parsers, so nothing here proves a template renders or that its
output works — that's layer 2.

## 2. Render-then-verify — `just lint-templates`

The core harness (`scripts/lint-templates.sh` — its header owns the
strategy and rationale). Renders for real: git-flow with release automation
on and off, git-flow + python, git-flow + typescript (overlays are layered
over a base render with `--overwrite` — a standalone overlay render has no
base slice to run). Copier post-gen tasks run for real too (`uv sync` /
`pnpm install`, `git init`, `lefthook install`), so lockfile generation is
exercised, not mocked.

Per render it asserts: expected file set (and no unrendered filename
survived), no unresolved template delimiters in the templated files,
JSON/TOML parse, lefthook actually installed a hook, and — the main event —
the rendered repo's **own** lefthook pre-commit/pre-push runs green. The
render's hooks _are_ the lint dispatch; there is deliberately no parallel
per-linter list here to drift (see the header for the history). On top:
an offline payload-vs-own-workflows action-pin agreement check, a
seeded-violation negative check (proves the checks check), `just --list`
on the typescript render (an overlay verb colliding with a base recipe
hard-errors every `just` invocation — see `docs/adding-an-overlay.md`),
and inline `tsc --noEmit` + `vitest` on the typescript render.

Local prereqs: the toolchain `lint-templates.yml` installs — uv, just,
lefthook, node, taplo, the base lint tools, and pnpm (CI: `pnpm/action-setup`
reading the overlay's `packageManager` pin; locally `corepack enable` gets
the same pinned version). CI: `lint-templates.yml` (same entry point).

## 3. Rendered-repo smoke — run the verbs

After touching an overlay, render into a temp dir (base first, then the
overlay with `--overwrite`, fixture answers) and run every verb a consumer
would: `just --list`, `just lint`, `just test`, `just typecheck`, the
overlay's format verb, `just adr "Title"`, and the app entry (`pnpm start`
/ `uv run <package>`). Layer 2 already runs the underlying commands (tsc,
vitest, the hooks); what this layer adds is the `just` recipe bodies
themselves — a broken recipe surfaces here, not there.

## 4. CI workflow execution — `act`

The overlay `test.yml` workflows never run in this repo's CI (they trigger
in consumer repos), so execute them against a render with
[`act`](https://github.com/nektos/act). Requires a running Docker daemon
(point `DOCKER_HOST` at colima's socket if that's the local runtime):

```sh
cd <render-dir>
git add -A && git commit -m fixture   # lefthook needs a HEAD; checkout provides one in real CI
act pull_request -W .github/workflows/test.yml \
  -e <(echo '{"pull_request": {"draft": false}}') \
  -P ubuntu-latest=catthehacker/ubuntu:act-latest
```

(The `draft: false` event payload matters — the job is draft-gated.) This
proves action resolution, the toolchain installs, and every step end to end.
It does not prove GitHub-side behavior: rulesets, required checks, caches,
the draft-gate as branch protection sees it — that's layer 6.

## 5. Retrofit — scratch-repo run

`scripts/retrofit-governance.sh` needs a target repo. Fixture: a temp git
repo with a fake `origin` remote URL, a commit, and a colliding file or two
(`README.md`, a manifest). Assert: the mutual-exclusion guard errors on two
overlay flags; a real run merges additively — colliding files become add/add
conflicts with both contents kept, nothing deleted; the dirty-tree refusal
fires on an uncommitted target.

## 6. Live e2e — the template-e2e sandbox

The only layer that touches real GitHub, in two dispatch-only workflows
(run from `main` only — infra pins the OIDC role trust to `refs/heads/main`,
infra ADR-0010):

- **`e2e-live.yml`** renders the payload, pushes a branch to
  `carpet-stain/template-e2e`, opens a draft PR, and proves what nothing
  local can — the draft-gate stays quiet for required checks, checks go
  green, rebase-merge lands, the branch auto-deletes. The `overlay` input
  (currently `typescript` only) layers that overlay over the render so its
  `test.yml` runs against real GitHub too, awaited explicitly since it
  isn't in the sandbox's required-check set:

  ```sh
  gh workflow run e2e-live.yml -f overlay=typescript
  ```

- **`e2e-release.yml`** proves the release automation live — dispatches the
  rendered `release-prepare.yml`, merges the release PR, asserts a real
  GitHub Release with usable notes. Needs an `e2e-live` run to have seeded
  content first.

The sandbox is a disposable render mirror: rsync `--delete` means each
`e2e-live` run swaps it to that run's flavor. `e2e-bootstrap.yml` reseeds
its `main` if it ever needs recreating.

## The gate pattern — verify toolchain claims empirically

Before building on an external tool's behavior, run the real thing against
the real check and let the result decide — don't trust docs or memory; a
render plus its own hooks is cheap. When a gate invalidates part of a plan,
fix it and journal the deviation on the PR (see #98's journal for worked
examples).
