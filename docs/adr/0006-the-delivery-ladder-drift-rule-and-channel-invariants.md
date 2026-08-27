# 0006. The delivery ladder, drift rule, and channel invariants

Date: 2026-08-27

## Status

Accepted

## Context

PST ships everything a consuming repo's `repos.tf` can't or shouldn't encode:
CI, hooks, recipes, lint config, language seeds, and (pending) engineering-
conventions prose. Two delivery mechanisms exist today, and nothing between
them: rung-1 reusable workflows (ADR-0004) for the governance CI jobs, and
copier at scaffold time for everything else. The copier path has no update
path once a repo is generated — the templates write no `.copier-answers`
file, so a repo evolves its copy directly from day one (git-flow/README.md's
"no `copier update` path" note) — but no ADR ever recorded that as a
deliberate choice; the root README's pointer at `docs/adr/` for it has
dangled since.

That gap is the actual cost: everything that isn't CI (hooks config,
justfile recipes, lint config, language seeds) is copy-once by default,
with drift silently accepted whether or not it's actually fine to drift.
Spike #94's inventory found `adr-guard` hand-copied into six repos at
five distinct blobs, and worse, fixes not propagating — a two-word
trigger fix (#95) cost six PRs, a `release-prepare` bugfix never reached
`dotfiles`.
ADR-0004 solved this for the CI-workflow class specifically (`workflow_call`
plus a moving `@v1` tag); this ADR generalizes the fix into a rule that
covers everything PST ships, not just CI.

## Decision

- **Chosen:** every artifact PST ships rides one of three rungs, chosen by
  one rule — **drift-sensitivity decides the rung**:

  | Rung                   | Mechanism                                                                                                                                                                                                                                                                                                                                                    | Update path                     | Divergence                                                                                                  |
  | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------- | ----------------------------------------------------------------------------------------------------------- |
  | 1 — tool-native remote | `@v1` reusable workflows (ADR-0004); lefthook `remotes:` pinned to `@v1`, self-contained jobs only (a `run:` step may reference only what travels with the remote config or sits on the same rung — script-backed jobs stay rung 2/3, confirmed live: a remote job invoking a consumer-local `scripts/*.sh` fails with `exit 127`, the script never travels) | follows the moving major tag    | pin or drop the ref                                                                                         |
  | 2 — sync channel       | PST-owned files listed in a per-repo ownership manifest; a scheduled reusable sync compares the manifest's recorded version against the latest GitHub Release and opens a PR on a gap                                                                                                                                                                        | reviewable PR, merge or decline | flip the file to repo-owned in the manifest — quiet, with a drift surfacing so upstream deltas stay visible |
  | 3 — copy-once seed     | copier at scaffold time, as today                                                                                                                                                                                                                                                                                                                            | never                           | n/a — repo-owned from birth                                                                                 |

  Rung 2 is **verbatim-only**: no per-repo rendering. A file needing
  repo-specific values stays rung 3, or splits into a synced core plus a
  repo-owned local include where the tool supports one.

- **Because:** copy-once was PST's silent default for everything outside
  CI, with no recorded reason and no update path — the exact shape that let
  #94's drift accumulate unnoticed. Naming the rule (drift-sensitivity, not
  file type or authoring convenience) makes "should this file update
  itself" a decision made once per artifact instead of inherited by
  accident. Rung 2 fills the gap between "changes constantly, needs a live
  call" (rung 1) and "never changes, or changing it is a repo-specific
  choice" (rung 3): hook configs, lint configs, and recipe files change
  occasionally, in a way a human should review, not silently inherit —
  a reviewable PR is exactly that middle ground. Verbatim-only keeps rung 2
  simple: templating on sync would reintroduce per-repo rendering logic
  that has to itself be kept correct across every consumer, the same
  fork-and-drift problem the rung exists to close.

- **Constraints:**
  - **Copy-once reversed as the default posture**: kept only where drift in
    a file is acceptable by design, not the fallback for anything that
    doesn't fit rung 1. A newly shipped artifact defaults toward a live
    rung unless a stated reason keeps it on rung 3.
  - A rung-1 config may reference only what travels with it or sits on the
    same rung — never a lagging rung-2/3 consumer-local script.
  - Divergence is a manifest flip (rung 2 → repo-owned), never a silent
    fork: the sync channel's own drift surfacing keeps a flipped file's
    pending upstream deltas legible.

Implementation mechanics for the sync channel — manifest format, PR shape,
collision behavior, the drift surfacing itself — belong to pst#147, not
here. The fleet reclassification against this rule is pst#148.

## Alternatives considered

- **Status quo — copy-once as the unstated universal default.** Rejected
  on the evidence already measured: #94's inventory, six PRs for a
  two-word fix, silently unpropagated bugfixes. This ADR exists because
  that default had never been examined, let alone chosen.
- **Two rungs only — live workflows (rung 1) and copy-once (rung 3), no
  sync channel.** Rejected: leaves everything that isn't a CI workflow
  (hook configs, lint configs, recipe files) with no update path short of a
  full retrofit re-run. The sync channel exists specifically to cover that
  class.
- **Rung 2 renders per-repo instead of verbatim-only.** Rejected: per-repo
  rendering means the sync mechanism itself has to stay correct across
  every consumer's variables, reproducing the same fork-and-drift risk this
  rung exists to close. A file that genuinely needs repo-specific values
  stays rung 3, or splits into a synced core plus a repo-owned local
  include.
- **Push-based fan-out for rung 2** (PST holds write credentials to every
  consumer and pushes changes directly). Rejected: needs a vended write
  token per consumer — the widest blast radius available — versus a
  pull/poll topology where no cross-repo write credential exists anywhere
  and a broken consumer breaks only itself.

## Consequences

- Copy-once needs a stated reason per file going forward, not just default
  inertia — the reclassification child (pst#148) audits every currently
  shipped file against this rule, expected to move some off rung 3 and
  confirm others belong there.
- A rung-1 config that references a repo-local script becomes a defect
  against this ADR, not a style question — CI doesn't enforce the
  constraint yet, review does.
- The sync channel (pst#147) is new infrastructure to build and maintain:
  a reusable workflow, a manifest format, and a drift-surfacing mechanism
  that don't exist yet.
- ADR-0004 is bookkept as this ladder's rung 1 — its own decision and
  consequences aren't restated or re-litigated here.
- Revisit if `carpet-stain/infra#208` (org migration) lands org-required
  workflows, which would fold rung 1 into org policy instead of a per-repo
  thin caller; or if pst#148's fleet diff finds rung 2's verbatim-only
  constraint too narrow for a file with legitimate per-repo divergence.
