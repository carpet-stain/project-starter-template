# This repo's own dev tooling — not the templates it hosts. A single file:
# unlike git-flow/template's base/lang split (the real composition mechanism
# a *generated* repo needs to layer a language overlay without editing the
# base), this repo has no overlay of its own to compose with, so the split
# bought nothing here — it was just an artifact of bootstrapping from the
# git-flow base (#10). git-flow/template/ and python/template/ keep the
# split; it's load-bearing there.

import? 'justfile.release'

# List recipes when invoked with no arguments.
_default:
    @just --list

# Run every pre-commit check (CI's lint job runs `just lint --tag base`).
lint *args:
    lefthook run pre-commit --all-files {{ args }}

# Create a numbered ADR from the template: `just adr "Short decision title"`.
adr *args:
    scripts/new-adr.sh {{ args }}

# Auto-format markdown with prettier (fixes what md-format only checks).
# Manual, deliberately NOT a lefthook job: `just lint` (and CI's lint job) run
# `lefthook run pre-commit --all-files`, and `prettier --write` always exits 0
# — hooking it would make md-format stop gating format in CI (dotfiles#406).
# Scoped via git ls-files to tracked markdown only, mirroring md-format's
# excludes (CHANGELOG is git-cliff-generated, agent-memory is heredoc notes).
format:
    git ls-files -z '*.md' ':!:CHANGELOG.md' ':!:.claude/agent-memory/**' | xargs -0 prettier --write

# Wraps the PATH-deployed record-token-cost (dotfiles owns the implementation,
# git-flow/README.md has the pointer); skips rather than fails if it's absent.
token-cost issue:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v record-token-cost >/dev/null 2>&1; then
      echo "token-cost: record-token-cost not on PATH — skipping (see git-flow/README.md)."
      exit 0
    fi
    record-token-cost {{ issue }}

# Render-then-verify the copier templates this repo hosts (git-flow/python) —
# see scripts/lint-templates.sh's own header for the strategy. Not part of
# the base/overlay template contract shipped to consumers (this repo hosts
# the templates; a generated repo doesn't).
lint-templates:
    scripts/lint-templates.sh
