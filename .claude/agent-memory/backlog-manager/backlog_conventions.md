---
name: backlog-conventions
description: Issue templates, title style, labels, and git workflow to mirror when filing project-starter-template issues
metadata:
  type: project
---

**Labels are terraform-governed** by `carpet-stain/infra`'s `repos.tf` `local.labels`, same
canonical set shared with `dotfiles`/`infra` (see that repo's `label_taxonomy.md` for the full
scheme — type + priority + `theme:`/modifier labels, don't duplicate the list here). Never
`gh label create/delete` directly — propose additions via infra's `repos.tf`.

**Stale-default-label drift — resolved.** The three GitHub-default labels (`help wanted`,
`question`, `invalid`) that survived repo creation untouched are now gone (verified absent via
`gh label list`, 2026-07-31). Durable operating fact this leaves behind: terraform's
`github_issue_label.this` only manages the canonical set — it does **not** remove pre-existing
defaults from a freshly-created repo, so any newly-scaffolded repo starts with those three until
someone clears them. Watch for it on the next repo infra provisions.

**Title style:** `type(scope): imperative lowercase description`, matching the shared convention.
Scopes seen so far: none formalized yet (too few issues) — infer from context, don't force
dotfiles'/infra's scope tables onto this repo without checking they actually fit.

**Git workflow:** short-lived feature branches off protected `main`, draft PR at first commit,
squash to one Conventional Commit, rebase-merge only — same model as `dotfiles`/`infra` (git-flow
base's own shipped convention, dogfooded here). `adr-guard.yml` gates `architecture`-labeled PRs
on touching `docs/adr/`.

**Label carry-over:** an issue moved in via `gh issue transfer` from `dotfiles`/`infra` keeps its
labels cleanly, since the taxonomy is the same terraform-governed set across all three repos.

**Governance-parity is a standing dotfiles→template propagation trickle.** Epic #27 (closed)
ported the first batch; new ports arrive per dotfiles governance change and land as individual
issues here (the mechanism is one-hop dotfiles→template — see `feedback-template-propagation` in
dotfiles' own store for the why). Expect a steady drip of "port dotfiles#NNN" issues; each is an
independent single-PR port, not one epic-worthy deliverable, unless a batch shares a real finish
line.

See [[repo-overview]].
