# Git-flow governance template

Copier template bundling the language-agnostic layer of this repo's
git/GitHub workflow (#136) — PR guards, optional release automation, and the
scoped-token credential pattern. Decisions and rationale live on #136 and its
spike #137; this is the mechanism.

Language-agnostic base under a language overlay (the Python starter at
`../python`, the TypeScript starter at `../typescript`): apply this template
first, then layer a language template on top.

The templates write **no `.copier-answers` file**, so there is no `copier
update` path — a repo is scaffolded once and evolved directly from then on
(ADR-0020, ADR-0021 in the template's source repo). Later template conventions
reach an existing repo by editing it, or by re-running the retrofit below.

## Use

```sh
git clone https://github.com/carpet-stain/project-starter-template.git
uvx copier copy project-starter-template/git-flow <new-project-dir>
```

Answers the GitHub owner/repo, the protected branch name, and whether to
include release automation, then a post-generation task runs `git init` and
`lefthook install`.

## Retrofit an existing, never-templated repo

```sh
project-starter-template/scripts/retrofit-governance.sh [--python|--typescript] <repo-dir>
```

`copier copy` can't do this safely — `--overwrite` replaces colliding files
(deleting the repo's real README), and the plain path prompts per file. The
script generates the template output into a temp tree and **git-merges**
it in as an unrelated history, which is the additive semantics wanted: an
absent file is created, an existing one becomes an `add/add` conflict with both
contents kept under markers for the operator to resolve, and nothing is ever
deleted. Answers are derived from the repo (origin URL, default branch, git
user); `--python`/`--typescript` layers that language overlay too (at most
one — ADR-0020). Re-run it later to pull a wholesale template refresh (shared
files re-conflict for you to resolve); smaller changes are usually quicker to
hand-apply. Greenfield repos don't need it — `copier copy`/`py-new.sh`/
`ts-new.sh` onto an empty dir has no collisions.

## What it produces

- `.github/workflows/pr-guards.yml` — one-commit-per-PR + Conventional
  Commit subject, gated on `draft == false`
- `.github/workflows/adr-guard.yml` — a PR labeled `architecture` must
  add/modify a `docs/adr/` file, else fail; unlabeled PRs report success, so
  it's safe as a required check. `bootstrap-branch-protection.sh` (step 4
  below) makes it a required check automatically because the guard ships
  here. See the ADR scaffolding below for what a labeled PR must produce.
- `.github/workflows/lint.yml` — the base CI: a `lint` job running the
  language-agnostic linters via `just lint --tag base`, gated on
  `draft == false`. A language overlay never touches it — it ships its own
  workflow (e.g. `test.yml`) running its own lefthook tag slice (ADR-0020)
- `.github/workflows/pr-code-review.yml` — advisory review by a
  non-Anthropic model, never a required check. Triggers on a PR carrying
  `needs-review`, or on one closing a `plan-approved` issue (plan-conformance
  review). Inert until an `OPENAI_API_KEY` repo secret exists; skips cleanly
  (green) without it — see `scripts/pr-review/run.mjs` and the workflow's own
  comments.
- `.github/workflows/epic-complete.yml` — closes an epic the moment its last
  same-repo sub-issue closes, behind a conservative cross-repo guard
  (dotfiles ADR-0047). Gates on the `epic` label from the canonical taxonomy
- `docs/adr/` scaffolding — `README.md` (what an ADR is, when to write one,
  the amendment style), `templates/template.md` (the Nygard template, with a
  self-sufficient bulleted `Decision`), `scripts/new-adr.sh` (stamps the
  next-numbered ADR from it and prints the significance checklist first — run
  via `just adr`, no adr-tools dependency), `.adr-dir`, and a seed
  `0001-record-architecture-decisions.md` so the directory exists in a fresh
  checkout
- `.github/workflows/release-prepare.yml` / `release-publish.yml` +
  `cliff.toml` + `justfile.release` (if release automation is included) —
  manual-dispatch version bump via git-cliff, a release PR, tag + GitHub
  release on merge; `justfile.release` adds the `cliff-preview` verb (a
  zero-side-effect preview of the version/changelog bump)
- `.github/pull_request_template.md` — the Conventional-Commit title reminder
  plus the doc-ownership checklist (decisions journal, ADR-when, supersede)
- `.github/ISSUE_TEMPLATE/` — bug / feature / spike forms whose default labels
  match the canonical label taxonomy every repo gets via infra's `repos.tf`
  (see the Bootstrap runbook below)
- `justfile` + `justfile.base` — the composition root (`import
'justfile.base'`, `import? 'justfile.lang'`, `import? 'justfile.release'`)
  and the base verbs: `just lint` (wraps `lefthook run pre-commit
--all-files`, the entry point CI shares), `just adr`, `just format`
  (fixes what the `md-format` lefthook job only checks — deliberately a
  recipe, not a hook, dotfiles#406), and `just token-cost <issue>` (posts
  per-issue token spend as a closing comment; a thin wrapper around
  `record-token-cost`, a PATH-deployed tool dotfiles owns and implements —
  see its own repo for the tool and the accounting model. Reads that
  maintainer's local Claude transcripts, so it's a no-op with a clear
  message, not a failure, on a machine without the tool on PATH). An overlay
  drops its verbs in `justfile.lang`; release automation drops
  `cliff-preview` in `justfile.release`
- `lefthook.yml` + `lefthook-base.yml` + `lefthook-lang.yml` — the composition
  root (`remotes:` PST's `lefthook-remote.yml` at `@v1` plus `extends:` both
  local files), the script-backed base jobs tagged `base`
  (`comment-concision`, `envrc-local-example-sync`), and an empty stub an
  overlay overwrites with its `lang`-tagged jobs. The rest of the base jobs
  (`actionlint`, `markdownlint-cli2`, `prettier`, `yamlfmt`, `gitleaks`,
  `shfmt`, `shellcheck`, `justfile-format`, `editorconfig-checker`) are
  self-contained and ride PST's `lefthook-remote.yml` live instead of a local
  copy (ADR-0006's rung 1)
- `.editorconfig`, `.markdownlint-cli2.yaml`, `.prettierrc.json`, `.yamlfmt`,
  `.gitleaks.toml` — the language-agnostic formatting and secrets-scanning
  baseline the lefthook jobs and CI enforce
- `README.md` — a starter front door filled from the copier answers, pointing
  at `docs/adr/` and `just lint` rather than restating them
- `.envrc` + `.envrc.local.example` — resolves `GH_TOKEN` from the vended
  token (routine credential) with a PAT escape hatch and a fail-closed
  sentinel, then aliases it to `GITHUB_TOKEN` for git-cliff's GitHub API
  lookups; see dotfiles' AGENTS.md Credentials section and infra ADR-0010
  for the design
- `.github/dependabot.yml` — weekly `github-actions` ecosystem updates

## What it deliberately doesn't produce

- **Branch protection.** Needs Administration-scope API access the routine
  `GH_TOKEN` deliberately lacks. Run
  `project-starter-template/scripts/bootstrap-branch-protection.sh` by hand
  with `env -u GH_TOKEN -u GITHUB_TOKEN` after generating the repo — see that
  script and #137's decision comment on #136 for why this stays a separate,
  explicitly-elevated step instead of a copier post-gen task.
- **The `RELEASE_PAT` secret.** `release-prepare.yml` needs a repo secret
  named `RELEASE_PAT` (a fine-grained PAT with Contents + Pull requests
  write) so its release PR triggers `pr-guards.yml` for real instead of
  landing in an approval-required state — see the workflow's own comments.
  Add it by hand: repo Settings → Secrets and variables → Actions.
- **Labels.** Several of the workflows above gate on a label that has to
  already exist on the repo — GitHub rejects applying a label that isn't
  defined, so a missing one doesn't error, it just makes the gate never
  fire. Tracked separately — see step 3 of the Bootstrap runbook below.
- **Global git config** (`committemplate`, `attributes`, `config`, `ignore`).
  Those are this machine's `$XDG_CONFIG_HOME/git/*`, deployed once by
  `macos/deploy.zsh` / `linux/deploy.sh` — already in effect for every repo
  on a machine with dotfiles installed, nothing to port per-project.
- **A language build/test pipeline.** The base ships `lint.yml` for the
  language-agnostic linters (above), but building and testing are
  language-specific — a language overlay (e.g. the Python starter) ships its
  own workflow alongside it, plus its `lefthook-lang.yml` and `justfile.lang`.

## Bootstrap runbook

The full sequence from idea to a governed repo. Each step is independent
and already idempotent — deliberately a documented sequence, not one fused
script, so a future Terraform cutover (repos-as-code, tracked on #136) can
replace steps 3–4 with `terraform apply` without touching 1–2, which
Terraform can't do (it manages GitHub API-level resources, not git
working-tree file content).

1. **Create the empty repo** — `gh repo create` or the GitHub web UI. A
   deliberate human step: picking the owner/org and visibility isn't
   something to automate.
2. **Scaffold the files** — `uvx copier copy project-starter-template/git-flow
   <dir>` (see Use, above). Layer a language template on top if applicable
   (e.g. `../python`). Push this first commit to `main` directly — a repo
   with zero commits has no `main` yet, and pushing any other branch name
   first makes GitHub adopt *that* branch as the new default instead. If
   you push a differently-named branch by mistake (e.g. via a PR flow),
   fix it with a branch rename
   (`gh api repos/{owner}/{repo}/branches/<branch>/rename -f new_name=main`),
   not another push — renaming an already-pushed branch doesn't touch
   content, so nothing needs re-review.

   A repo created via `carpet-stain/infra`'s `repos.tf` already has branch
   protection and labels active before this first commit ever lands —
   `tofu apply` provisions both together with repo creation. A direct push
   to `main` is then rejected (`GH013`: required status checks with nothing
   to report them yet, since there's no PR/CI run behind a bare push). Use
   the branch-rename workaround above instead of retrying the push — a
   rename doesn't re-trigger the ruleset's push check. **Skip steps 3–4
   entirely** for such a repo: both are already done by the same
   `tofu apply`; re-running `bootstrap-branch-protection.sh` would likely
   422 against the ruleset that already exists.

3. **Apply labels** — nothing to do for a repo created via infra's
   `repos.tf` (see the note under step 2 above): `local.labels` is the
   canonical definition, applied to every `carpet-stain` repo including this
   template's label-gated CI needs. There's no other tracked path for
   applying labels to a repo bootstrapped outside infra — a consumer outside
   `carpet-stain` has to create the ones this template's CI reads by hand
   (repo Settings → Labels, or the GitHub API), or that CI silently never
   fires:
   - `architecture` — `adr-guard.yml`'s required-ADR gate
   - `needs-review` — requests `pr-code-review.yml`'s advisory review
     on demand
   - `plan-approved` on an issue a PR closes — auto-triggers
     `pr-code-review.yml`'s plan-conformance review

4. **Apply branch protection** — same directory:
   `env -u GH_TOKEN -u GITHUB_TOKEN project-starter-template/scripts/bootstrap-branch-protection.sh`.
   Must come after step 2: it hardcodes `single commit` + `conventional
commit` as required checks, which only exist once `pr-guards.yml` is in
   the repo — running this first leaves required checks that never report,
   permanently blocking merges. Also needs GitHub Pro or a public repo (the
   script's own comments cover this gotcha). It requires `adr guard`
   automatically too, since this template ships `adr-guard.yml`.
5. **Add the `RELEASE_PAT` secret** by hand, if release automation was
   included in step 2 — see "What it deliberately doesn't produce," above.

Steps 3 and 4 both need the elevated `env -u GH_TOKEN -u GITHUB_TOKEN` session
(routine `GH_TOKEN` deliberately lacks Issues/Administration scope; both vars
drop because `.envrc` aliases `GITHUB_TOKEN` to the same scoped token) — see
AGENTS.md's Credentials section.

## Known limitation

A generated repo is this base plus **at most one** language overlay — never
more (ADR-0020). The layers own disjoint files, composed natively: separate
workflow files for CI, `import?` for the justfile, `extends` + an
overwritable stub for lefthook, with `base`/`lang` lefthook tags splitting
the CI slices. Copier's inability to merge files across templates therefore
only bites the two files both layers still ship: `.gitignore` (the overlay
replays the base's single `.envrc.local` entry — git has no include
mechanism for tracked ignores) and the seeded `README.md` (pointer-pure and
structurally identical, so the overwrite is harmless).
