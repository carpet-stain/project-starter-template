---
name: repo-overview
description: What project-starter-template is, its layered composition model, and where its docs/ADRs live — orient here before filing issues
metadata:
  type: project
---

`carpet-stain/project-starter-template` is a copier-template host: a language-agnostic
**git-flow governance base** (`git-flow/template/` — branch protection expectations, PR guards,
release automation, labels, ADR discipline) plus **language overlays** (currently just
`python/template/` — uv/ruff/pyright/pytest) that compose *into a generated consumer repo* via
`copier copy`. Extracted from `carpet-stain/dotfiles` (dotfiles#309's epic; #136/#129 own the
original design decisions) so dotfiles could become config-only. Governed by
`carpet-stain/infra`'s `repos.tf` — same canonical label set, branch-protection ruleset, and
repo-creation flow as `dotfiles`/`infra` themselves (see [[reference-infra-repo]] equivalent in
that repo's own memory — this repo doesn't keep its own copy, cross-check there).

**Composition model — ADR-0020 (ported from dotfiles):** a generated repo is the git-flow base
plus **at most one** overlay, never more. Base and overlay own disjoint files by design — overlays
add to `justfile.lang`/`lefthook-lang.yml`/their own CI workflow, never touch
`justfile.base`/`lefthook-base.yml`/`lint.yml`. Two files both collide on regardless
(`.gitignore`, the seeded `README.md`) — `--overwrite` is deliberately safe there, documented as a
"known limitation" in `git-flow/README.md`.

**This repo's own root tooling is a separate concern from what it ships.** Bootstrapped *from* the
git-flow base itself (dogfooding, project-starter-template#1), so its own root `justfile`/
`lefthook.yml` inherited the same base/lang split mechanism the templates need for composing into
*other* repos — but this repo isn't itself a consumer with an overlay, so that split is currently
pure bootstrap-accident overhead here, not a mechanism this repo needs. #10/#12 track simplifying
it. **Never conflate this with `git-flow/template/*`/`python/template/*`** — those must keep the
base/lang split; that's the actual shipped composition mechanism other repos depend on.

Key layout: `git-flow/` (base template + its own `copier.yml`), `python/` (overlay template +
`copier.yml`), `scripts/` (this repo's own dev tooling — `new-adr.sh`, `check-envrc-local-example.sh`,
`lint-templates.sh`), `docs/adr/` (this repo's own ADRs, `just adr` only).

**Verification tooling:** `scripts/lint-templates.sh` (165 lines) — render-then-lint for the copier
templates (`.jinja`/copier syntax breaks yaml/toml/py parsers directly on the raw files, so this
renders with fixture answers first). Moved verbatim from dotfiles (#310/PR#348, closed unmerged
there once this repo's own copy landed via project-starter-template#2/PR#7 — verified byte-identical).
Three callers: lefthook pre-commit (`--jinja` mode, cheap raw pass), lefthook pre-push (full
render-then-lint), CI (`just lint-templates`).
