#!/usr/bin/env bash
# Advisory pre-push nudge (#53, companion to dotfiles#493/#496): this repo's
# governance surface is layered (ADR-0020), not single like dotfiles' — a
# lint/CI change usually needs to land on *both* this repo's own root dev
# tooling and the shipped template's (git-flow/overlay) mirrored copy, or the
# two silently drift (observed here repeatedly: #17/#19/#52 each needed the
# same fix in both places). So unlike dotfiles' one-directional "propagate to
# the other repo" reminder, this is a same-repo, both-sides-or-neither check:
# a push touching one side's governance surface but not the other's gets a
# reminder to evaluate the sibling side. Broad globs, not a hand-maintained
# file list, so a new governance file doesn't silently fall outside the check.
#
# Known blind spot, accepted: fires on any one-sided touch, including a
# legitimate one (not every root tooling change belongs in the shipped
# template, and vice versa); it only nudges, never verifies the asymmetry
# was deliberate.
set -uo pipefail

if ! git rev-parse --verify origin/main >/dev/null 2>&1; then
  echo "check-governance-propagation: skipped: no origin/main ref"
  exit 0
fi

changed="$(git diff --name-only origin/main...HEAD)"

root_pattern='^(\.github/workflows/.*|lefthook\.yml|justfile|\.editorconfig|\.gitleaks\.toml|\.markdownlint-cli2\.ya?ml|\.yamlfmt|\.prettierrc\.json)$'
template_pattern='^(git-flow|python|typescript)/template/.*(\.github/workflows/.*|lefthook.*\.ya?ml|justfile.*|\.editorconfig|\.gitleaks\.toml|\.markdownlint-cli2\.ya?ml|\.yamlfmt|\.prettierrc\.json|cliff\.toml.*)$'

touched_root=0
touched_template=0
grep -qE "$root_pattern" <<<"$changed" && touched_root=1
grep -qE "$template_pattern" <<<"$changed" && touched_template=1

if [ "$touched_root" -eq 1 ] && [ "$touched_template" -eq 0 ]; then
  echo "check-governance-propagation: this branch touches this repo's own governance surface but not the shipped templates' — evaluate propagating to git-flow/template/ (and python/ or typescript/ template/ if relevant)"
elif [ "$touched_template" -eq 1 ] && [ "$touched_root" -eq 0 ]; then
  echo "check-governance-propagation: this branch touches the shipped template's governance surface but not this repo's own — evaluate whether this repo's own root tooling needs the same change"
fi

exit 0
