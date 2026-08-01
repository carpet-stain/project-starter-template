---
name: pr-reviewer-port
description: Template's advisory PR reviewer is a full generation behind dotfiles' DIY reviewer; the on-hand OPENAI_API_KEY is OpenRouter-shaped, which kills the anc95/OpenAI-direct path
metadata:
  type: project
---

The template payload `git-flow/template/.github/workflows/pr-code-review.yml` still runs the old
`anc95/ChatGPT-CodeReview` action against `api.openai.com` directly. dotfiles has since **replaced
that action wholesale** with a DIY reviewer (`scripts/pr-review/run.mjs`, dotfiles#330):
OpenRouter-native, structured `FINDINGS_SCHEMA` output, real one-click per-line suggestions, and
plan-conformance review (dotfiles#458 — fetches the closed issue's plan via GraphQL
`closingIssuesReferences` and checks the diff against it). dotfiles#490/PR#501 then bumped that
DIY reviewer's model to `openai/gpt-5.6-sol` on OpenRouter. So the template is behind on the
**action, the provider, and the plan-conformance behavior** — not just a model string. dotfiles'
own reviewer rationale is ADR-0025 (different-model eyes, NOT cost).

**Live infra fact (not derivable from code):** the `OPENAI_API_KEY` secret the maintainer has on
hand is OpenRouter-shaped (`sk-or-v1-...`), verified 2026-08-01 via throwaway PR #71. The anc95
action calls `api.openai.com` and cannot authenticate with it — so the template's current
option-1 path (keep anc95, bump MODEL) is non-functional against the real credential. dotfiles'
OpenRouter-native run.mjs is exactly what that key fits.

**Label mismatch:** the template has a `needs-review` label ("Requests the advisory PR review
(pr-code-review.yml) — independent of the architecture/ADR label"), but the template workflow
gates only on `contains(labels, 'architecture')` and never reads `needs-review`. The label
promises a trigger the workflow doesn't implement — the label was seemingly pre-added in
anticipation of the port. dotfiles' run.mjs honors `needs-review` as the on-demand trigger
(mirrors dotfiles#456's label-overload split). Porting the reviewer resolves this; it's not a
separable fix.

**Pre-existing bug in the current template reviewer:** anc95 only handles
`pull_request.opened`/`.synchronize` internally, so a run triggered purely by a `labeled` event
silently no-ops (empty success). Subsumed by the port; not worth its own issue.

**Why:** #60 was filed narrow (option 1 = model bump only) on the reasoning "close the weak-model
gap now without blocking on the bigger port decision." The OpenRouter-key finding falsifies that
premise — option 1 can't run on the actual key, so the narrow path closes nothing. The port
(option 2) is the path that both matches the credential and actually closes #60's stated problem.

**How to apply:** if #60 or PR #70 comes up again — the maintainer was weighing whether to
re-scope #60 to the port (architecture-labeled + needs-plan-review, cite dotfiles ADR-0025 /
\#330 / #458) and close PR #70. Check whether that scope decision got settled before acting;
it's a scope fork that needs the maintainer's explicit call, not an agent default. See
[[repo-overview]].
