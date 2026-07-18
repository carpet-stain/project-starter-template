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

**Known drift, not yet cleaned up:** this repo still carries three stale GitHub-default labels
(`help wanted`, `question`, `invalid`) that `dotfiles` already retired as "dead solo-repo defaults"
(no external contributors/questions in a solo-owned repo) — terraform's `github_issue_label.this`
only manages the canonical set, it doesn't remove pre-existing defaults from a freshly-created
repo, so these survived repo creation untouched. Flagged to the user 2026-07-18, not removed
unilaterally (a label deletion across a repo is worth a heads-up even for GitHub defaults nothing
governs). Revisit if the user confirms.

**Title style:** `type(scope): imperative lowercase description`, matching the shared convention.
Scopes seen so far: none formalized yet (too few issues) — infer from context, don't force
dotfiles'/infra's scope tables onto this repo without checking they actually fit.

**Git workflow:** short-lived feature branches off protected `main`, draft PR at first commit,
squash to one Conventional Commit, rebase-merge only — same model as `dotfiles`/`infra` (git-flow
base's own shipped convention, dogfooded here). `adr-guard.yml` gates `architecture`-labeled PRs
on touching `docs/adr/`.

**Backlog state as of 2026-07-18 grooming sweep:** first four issues (#10-#13) all triaged
(type+priority present). #10/#12 cross-linked (same theme: simplify this repo's own bootstrapped
tooling, not the shipped templates) — not merged into one issue, each has disjoint Acceptance.
#13 arrived via `gh issue transfer` from `dotfiles`#349 (its subject, `git-flow/README.md`'s
bootstrap runbook, now lives here) — labels carried over cleanly since the taxonomy is shared.

See [[repo-overview]] and [[open-work]].
