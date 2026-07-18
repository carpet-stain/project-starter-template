---
name: open-work
description: Snapshot of the first backlog-grooming pass (2026-07-18) — what's open, ready, and why
metadata:
  type: project
---

**Four open issues as of the first grooming sweep (2026-07-18), all `priority: low` except #13
(`medium`):**

- **#10** — merge this repo's own `justfile`/`lefthook` composition into single files (bootstrap
  overhead, not the shipped template mechanism — see [[repo-overview]]). Cross-linked with #12.
- **#11** — write a guide for authoring a new language overlay. Low urgency by design: only one
  overlay (`python/`) exists today: the guide earns more value once a second overlay is actually
  being authored, not speculatively now.
- **#12** — evaluate moving small `scripts/*.sh` (`new-adr.sh`, `check-envrc-local-example.sh`)
  into `just` recipes. Explicitly excludes `lint-templates.sh` (165 lines, three distinct
  callers — a genuine standalone-script shape, not a `just`-recipe candidate). Cross-linked
  with #10.
- **#13** — bootstrap-runbook doc gap (branch protection pre-provisioned by infra's `tofu apply`
  breaks the runbook's "push first commit directly" step). Transferred in from `dotfiles`#349;
  ready to act, no dependency.

**Nothing currently blocked.** All four are independently actionable; none gates the others.

**Cross-repo context worth knowing:** the extraction that created this repo
(`dotfiles`#309/#311/#312, `infra`#14/#15) is now fully landed as of 2026-07-18 — `dotfiles` is
mid-purging its now-duplicated copies (`dotfiles`#312, `priority: medium`, unblocked). `infra`#20
(fix `repos.tf`'s Python-only description/topics for this repo, now that the real README exists)
is unblocked too (this repo's README PR, #8, merged). Neither is this repo's own issue to track —
noted here only so a future session doesn't re-derive the cross-repo state from scratch.

See [[repo-overview]] and [[backlog-conventions]].
