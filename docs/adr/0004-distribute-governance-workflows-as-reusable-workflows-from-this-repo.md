# 0004. Distribute governance workflows as reusable workflows from this repo

Date: 2026-08-18

## Status

Accepted

## Context

Every governance CI workflow (adr-guard, pr-guards, lint, epic-complete,
pr-code-review, release-\*) is hand-copied into each of six repos and
drifts — spike #94's inventory found adr-guard alone at 5 distinct blobs,
and worse, _decisions_ rotting un-propagated: the adr-guard trigger fix
(#95) took one PR per repo; a release-prepare bugfix never reached
dotfiles; pr-code-review runs in three generations (third-party action →
repo-secret DIY → OIDC/SSM DIY), with the payload seeding new repos from
the older credential generation. Logic is otherwise ~90% convergent —
divergence is mostly comments and checkout-version skew — so
centralization fits the content.

Constraints that shaped the decision (full evidence trail on #94):

- The repos live on a **personal account**: org-level required workflows
  and starter-workflow templates are org-only. The one first-party
  cross-repo distribution primitive available today is the **reusable
  workflow** (`workflow_call`).
- Required checks are the enforcement backbone: rulesets require
  `adr guard`, `single commit`, `conventional commit` (+ `issue link` in
  dotfiles). A job called through a reusable workflow reports as
  `<caller job> / <called job>` — adopting reusable workflows **renames
  every required check** (one-time, six rulesets, Administration scope).
- The draft-gate pattern (job-level `if:` — skipped reads as passing)
  **breaks if the `if:` sits on the caller job**: the called workflow is
  never expanded and its required check hangs as "Expected" forever. The
  gate must move inside the called workflow's jobs, which see the
  caller's `github.event` (docs-confirmed; the skipped-inside-callee
  composed-name case is the bounded live experiment in the follow-up).
- OIDC claims describe the caller; AWS trusts only `sub`/`aud`, and infra
  pins exact repo+ref subs. Centralizing an OIDC-using job means either
  caller-scoped trust (callee invisible to AWS) or per-repo sub
  customization — so OIDC jobs are excluded from the first wave.

## Decision

Host `workflow_call` versions of the governance workflows **in this
repo**, next to the template that already seeds them; every governed repo
keeps a thin caller per workflow that `uses:` this repo's copy at a
**SHA pin**, bumped by each repo's existing Dependabot. Per-repo variance
(protected branch, release automation) travels as `workflow_call` inputs.
Draft-gate `if:`s live inside the called jobs, never on the caller.

Scope the first wave to the plain-token guards — adr-guard, pr-guards,
lint, epic-complete. `pr-code-review` (OIDC) and the release workflows
(RELEASE_PAT, `workflow_dispatch`) stay per-repo until the follow-up
decides their credential story. The git-flow payload ships the thin
callers, so new repos inherit the mechanism.

Placement of workflows and this ADR: **this repo**. The topology today is
dotfiles = meta-governance/agent-rules ADRs (0020/0021/0038/0044…),
project-starter-template = template- and workflow-content decisions
(0002, 0003 are precedent), infra = credentials and rulesets. Workflow
_content_ is authored here and seeded from here; the one-time ruleset
re-point is infra-seat work. Cross-repo ADR references must carry the
repo name (`dotfiles ADR-0020`) — infra has its own unrelated ADR-0020,
so bare references ambiguate.

Propagation semantics after adoption (the axis that decides): a
governance change = one PR here, then one Dependabot pin-bump PR per repo
— automated, reviewable, rollback = revert the bump. No hand-copying, no
third-party sync machinery, blast radius controlled by the pin.

Interaction with infra#208 (org migration): forward-compatible. An org
unlocks ruleset-required workflows; the centralized `workflow_call` files
are exactly what an org ruleset would require, so the thin callers become
optional enforcement sugar, not rework.

## Alternatives considered

- **Org-level shared/required workflows now** — not available on a
  personal account; adopting it means gating governance on the #208 org
  migration, which has no date. Kept as the upgrade path, rejected as the
  mechanism.
- **Template-as-SoT auto-sync** (repo-file-sync-action /
  actions-template-sync) — third-party actions needing a cross-repo PAT,
  producing one auto-PR per repo per change (same N merges as today, plus
  conflict risk on locally-diverged files, plus a supply-chain
  dependency). No first-party mechanism exists. Rejected: pays N forever
  to avoid a one-time migration.
- **Status quo (hand-copy + checklist discipline)** — the baseline just
  measured: a two-word trigger fix cost six PRs (#95), and the inventory
  shows fixes silently not propagating for months. Rejected on evidence.

## Consequences

- One-time migration: extract `workflow_call` versions, add thin callers,
  re-point six rulesets to composed check names (Administration scope,
  elevated credential, infra seat) — tracked in the follow-up epic, gated
  on a bounded live experiment for the three docs-ambiguous behaviors
  (skipped-inside-callee check naming, cross-repo `secrets: inherit` on a
  personal account, exact composed-name strings in the ruleset picker).
- The called workflows' job names become a cross-repo contract: renaming
  a job inside a shared workflow breaks six rulesets. Refactors of shared
  workflow internals are breaking changes and version like one.
- Dependabot bump PRs replace hand-propagation; a repo can lag a pin
  deliberately (blast-radius control) at the cost of temporary fleet
  divergence that is at least visible as an open PR.
- The payload thins: new repos get callers instead of full workflow
  bodies, so payload/consumer drift for the shared set disappears.
- Revisit when #208 lands (upgrade enforcement to org required
  workflows) or if a shared workflow needs OIDC (decide per-repo sub
  customization then).
