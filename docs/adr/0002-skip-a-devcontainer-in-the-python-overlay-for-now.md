# 0002. Skip a devcontainer in the python overlay for now

Date: 2026-08-09

## Status

Accepted

## Context

Spike #79. `golden-ratio-dual-gate` and `deal-finder` both scaffold from this template. A
one-off `.devcontainer/` dropped into either drifts on the next template refresh — the template
doesn't own it, so it orphans. If a devcontainer is worth having, it belongs in an overlay here
so it propagates to every consumer, not as a per-repo artifact.

Two arguments were on the table, tested rather than assumed:

- **Reproducible env.** `golden-ratio-dual-gate`'s actual dependencies (pandas, numpy, requests,
  yfinance) all ship prebuilt wheels — no system-library compilation step. `uv.lock` +
  `.python-version` already pins the interpreter and every dependency exactly. There's no
  meaningful "works on my machine" gap left for a container to close for this stack.
- **Agent sandbox / credential boundary.** `golden-ratio-dual-gate`'s own roadmap puts
  Schwab-connected execution (real brokerage credentials) in Phase 3, explicitly "not scoped in
  detail yet... revisit once phases 1-2 are proven out." No code touches brokerage creds today —
  the threat is real but not current. And the org's actual established pattern for "keep
  crown-jewel secrets off the ambient environment" (infra ADR-0009) is gated fetch-at-invocation
  via a Keychain ACL prompt, not container isolation — a host-level mechanism, already proven,
  that doesn't need a devcontainer to work.

The maintainer's own flagged reference (domenic.me/agentic-coding-setup/) reaches the same
conclusion for the closely-analogous agent-sandboxing case: devcontainers "haven't yet crossed
the cost/benefit threshold" given the setup/maintenance overhead against marginal risk, when
other safeguards (frequent commits as a safety net) already exist.

Also surfaced during the spike, correcting a premise in the issue: `golden-ratio-dual-gate`'s
`.copier-answers.yml` traces to `dotfiles/python` (a separate, sibling template that supports
`copier update`), not to this repo's own `python` overlay. This repo's git-flow and python
templates write no answers file (confirmed by a live render) — there is no `copier update` path
for either. Had the answer here been "ship it," a devcontainer added to this repo's overlay would
reach an already-scaffolded repo only via `retrofit-governance.sh`'s git-merge mechanism, not
`copier update` — the issue's "how it survives copier update" sub-question doesn't apply to this
repo's own templates as framed.

## Decision

Don't ship a `.devcontainer/` in the `python` overlay (or the `git-flow` base) right now. The
reproducibility gap `uv` doesn't already close is not evident for the one real consumer
(`golden-ratio-dual-gate`), and the credential-boundary case is speculative until Phase 3
(Schwab-connected execution) actually starts getting built — at which point ADR-0009's
established gated-fetch pattern is the more likely fit anyway, not a container.

Revisit when `golden-ratio-dual-gate` starts Phase 3 work: re-run this cost/benefit with real
code touching brokerage credentials on the table, not a roadmap entry.

## Alternatives considered

- **Ship a devcontainer in the `python` overlay now**, ahead of Phase 3. Rejected — building and
  maintaining a rendered artifact (image build time, `act`-based local CI interaction, drift
  across consumers) against a credential threat that doesn't exist in code yet is paying the cost
  before the benefit is real.
- **Ship a devcontainer in the `git-flow` base** (broader than python-only), so every consumer
  gets it regardless of language overlay. Rejected for the same reason as above, more broadly —
  no consumer of the base template has surfaced a reproducibility or credential-boundary need at
  all.
- **Solve the credential boundary with a container regardless of the reproducibility argument.**
  Rejected — ADR-0009 already establishes a proven, host-level pattern (gated fetch-at-invocation,
  never ambient) for exactly this threat model; a devcontainer would be a second, weaker
  mechanism for the same problem, not a necessary one.

## Consequences

No new rendered artifact to maintain in either template; `uv sync` stays the whole "get a working
environment" story for the python overlay. `golden-ratio-dual-gate` and `deal-finder` stay on the
host, unsandboxed, until this is revisited — acceptable because neither currently holds execution
credentials. When Phase 3 lands, re-open this decision with ADR-0009's pattern as the starting
comparison, not a fresh blank-slate devcontainer proposal.
