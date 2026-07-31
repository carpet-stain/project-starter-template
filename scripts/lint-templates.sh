#!/usr/bin/env bash
# Render-then-verify for the copier templates (git-flow base, git-flow+python
# overlay) hosted here — see dotfiles#310 (original) and
# project-starter-template#41 (this design). The .jinja/copier syntax breaks
# yaml/toml/py parsers directly, so this validates the *rendered output*.
#
# Rather than hand-rolling a parallel per-linter dispatch keyed on file
# extension (the old approach — see git history), each render's own
# `lefthook run pre-commit --all-files` does the linting: the same entry
# point a real consumer's CI/local hooks run. A lefthook job added to
# lefthook-base.yml/lefthook-lang.yml is exercised here automatically, with
# no second list to remember to update — the old dispatch had already
# drifted (gitleaks/shfmt/editorconfig-checker/justfile-format shipped in the
# template with nothing here running them) before this rewrite (#41).
#
# Usage:
#   lint-templates.sh              full render-then-verify (just lint-templates, CI)
#   lint-templates.sh --jinja F...  raw j2lint pass over F... (lefthook pre-commit,
#                                   passed {staged_files}) — cheap, no render
set -euo pipefail

# Run via lefthook's pre-push hook, GIT_DIR/GIT_WORK_TREE/GIT_INDEX_FILE are
# set to *this* repo's git dir for the hook's own use — but copier's `git`
# calls (resolving a template source's latest tag) inherit them too, and a
# GIT_DIR pinned to the wrong repo makes `git ls-remote` on the template
# path itself fail with "does not appear to be a git repository". Unset
# before any copier invocation so its internal git calls see plain ambient
# state, same as running this script by hand.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_PREFIX 2>/dev/null || true

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

fail=0

# j2lint_pass F...  ->  raw jinja syntax check on any *.jinja files in F...
#
# Two known false-positive classes are dropped here, not linted at all
# (both are caught for real by the render-then-verify pass instead):
#   - cliff.toml.jinja embeds git-cliff's own Tera template inside a Jinja
#     `{% raw %}` block; j2lint doesn't know to skip raw-block contents and
#     misreads Tera's {{ }}/{% %} as malformed Jinja.
#   - release-prepare/publish.yml.jinja and pr-guards.yml.jinja use GitHub
#     Actions' own `${{ }}` syntax literally (this template remaps copier's
#     variable delimiters to `[[ ]]` in copier.yml's _envops specifically so
#     `${{ }}` passes through untouched) — j2lint doesn't know about that
#     remap and misreads `${{ secrets.X }}` as a plain Jinja variable.
j2lint_pass() {
  local jinja_files=()
  for f in "$@"; do
    case "$f" in
      *.jinja) ;;
      *) continue ;;
    esac
    case "$f" in
      *cliff.toml*.jinja) continue ;;
      *release-prepare.yml*.jinja | *release-publish.yml*.jinja) continue ;;
      *pr-guards.yml.jinja) continue ;;
      *) jinja_files+=("$f") ;;
    esac
  done
  if [ "${#jinja_files[@]}" -gt 0 ]; then
    uvx j2lint "${jinja_files[@]}" || fail=1
  fi
}

if [ "${1:-}" = "--jinja" ]; then
  shift
  j2lint_pass "$@"
  exit "$fail"
fi

cleanup_dirs=()
cleanup() {
  for d in "${cleanup_dirs[@]}"; do
    rm -rf "$d"
  done
}
trap cleanup EXIT

# render <template-dir> [copier -d/-- flags...]  ->  prints the render dir
render() {
  local template=$1
  shift
  local dir
  dir=$(mktemp -d)
  cleanup_dirs+=("$dir")
  uvx copier copy --trust --defaults "$@" "$template" "$dir" >&2
  printf '%s\n' "$dir"
}

echo "==> j2lint (raw jinja syntax)"
mapfile -d '' all_jinja < <(find git-flow/template python/template -name "*.jinja" -print0)
j2lint_pass "${all_jinja[@]}"

# The git-flow payload's own *.jinja sources, by their rendered (post-suffix-
# strip, post-{% if %}-wrapper) destination path. A small explicit list, not
# derived from `find template -name '*.jinja'`, because the {% if %}-wrapped
# filenames need that same conditional evaluated to know their rendered path
# — Jinja-evaluating a filename in bash isn't worth it for 8 files that
# rarely change.
GIT_FLOW_ALWAYS_JINJA_FILES=(
  README.md
  .github/workflows/adr-guard.yml
  .github/workflows/lint.yml
  .github/workflows/pr-guards.yml
)
GIT_FLOW_RELEASE_GATED_FILES=(
  cliff.toml
  justfile.release
  .github/workflows/release-prepare.yml
  .github/workflows/release-publish.yml
)

# assert_file_set <dir> <release_automation: true|false>  ->  the gated
# files land (or don't) per the answer, and no unrendered filename survived
# (a stray *.jinja suffix, or an unevaluated {% if %} wrapper).
assert_file_set() {
  local dir=$1 release_automation=$2 f
  for f in "${GIT_FLOW_RELEASE_GATED_FILES[@]}"; do
    if [ "$release_automation" = true ]; then
      [ -e "$dir/$f" ] || {
        echo "expected $f (include_release_automation=true) but it's missing from $dir" >&2
        fail=1
      }
    else
      [ -e "$dir/$f" ] && {
        echo "$f present in $dir but include_release_automation=false" >&2
        fail=1
      }
    fi
  done
  local stray
  stray=$(find "$dir" -name '*.jinja' -o -name '*{%*')
  if [ -n "$stray" ]; then
    echo "stray unrendered filename(s) in $dir:" >&2
    printf '%s\n' "$stray" >&2
    fail=1
  fi
}

# assert_no_unresolved <dir> <delimiter> <file...>  ->  none of the given
# already-rendered files still contain the template's own variable
# delimiter. Scoped to the specific files copier actually templated, not a
# whole-tree grep: this template remaps its variable delimiter to `[[ ]]`
# (git-flow) precisely so GitHub Actions' `${{ }}` isn't a collision, and the
# python overlay's default `{{ }}` delimiter is deliberately left unresolved
# inside cliff.toml's `{% raw %}` git-cliff/Tera block — a blind `grep -r`
# for either delimiter false-positives on both of those, plus on unrelated
# `[[ ... ]]` bash test syntax and `[[table]]` TOML array-of-tables syntax
# elsewhere in the render.
assert_no_unresolved() {
  local dir=$1 delim=$2 f hits
  shift 2
  for f in "$@"; do
    [ -f "$dir/$f" ] || continue
    if hits=$(grep -nF -- "$delim" "$dir/$f"); then
      echo "unresolved '$delim' left in $dir/$f:" >&2
      echo "$hits" >&2
      fail=1
    fi
  done
}

# assert_lefthook_installed <dir>  ->  the copier post-gen task's
# `lefthook install` actually landed a hook (implicitly required already —
# `set -euo pipefail` means a failing post-gen task aborts render() — this
# makes the specific claim visible rather than leaning on that side effect).
assert_lefthook_installed() {
  local dir=$1
  [ -x "$dir/.git/hooks/pre-commit" ] || {
    echo "lefthook install did not land an executable pre-commit hook in $dir" >&2
    fail=1
  }
}

# assert_toml_valid <dir>  ->  structural validity only, not `taplo fmt
# --check`: taplo collapses a short array to one line and keeps a long one
# expanded, and the threshold is the *rendered* line length — which depends
# on the answers (author name/email, description), not the template. No
# static template text is fmt-stable for arbitrary answers, and the rendered
# repo doesn't wire toml formatting into its own lefthook config either, so
# `fmt --check` here would flag an inherent property of jinja-templated
# TOML, not a template defect. Kept as its own check (not part of the
# rendered lefthook run below): the rendered repo doesn't lint its own TOML
# either, so this is coverage the harness adds deliberately, not delegated.
assert_toml_valid() {
  local dir=$1
  local toml_files
  mapfile -t toml_files < <(cd "$dir" && git ls-files '*.toml')
  [ "${#toml_files[@]}" -gt 0 ] || return 0
  (cd "$dir" && taplo lint "${toml_files[@]}") || fail=1
}

# run_rendered_hook <dir> <pre-commit|pre-push>  ->  stage everything and run
# the rendered repo's own lefthook slice, exactly as a contributor or its
# generated CI would (`just lint` / lint.yml.jinja's `just lint --tag base` /
# test.yml's `lefthook run pre-commit --tag lang`) — unscoped here so both
# the base and (when present) language-overlay jobs run in one pass.
run_rendered_hook() {
  local dir=$1 hook=$2
  git -C "$dir" add -A
  (cd "$dir" && lefthook run "$hook" --all-files --no-tty) || fail=1
}

# assert_hook_catches_a_real_violation <dir>  ->  seed one violation and
# confirm the rendered pre-commit hook actually fails on it. Proves the
# checks check, not just that clean fixture input happens to pass.
assert_hook_catches_a_real_violation() {
  local dir=$1
  printf 'trailing whitespace   \n' >>"$dir/README.md"
  git -C "$dir" add -A
  if (cd "$dir" && lefthook run pre-commit --all-files --no-tty) >/dev/null 2>&1; then
    echo "negative check failed: seeded trailing whitespace in $dir/README.md and the rendered pre-commit hook still passed" >&2
    fail=1
  fi
}

echo "==> rendering + verifying git-flow (include_release_automation=true)"
base_on=$(render git-flow -d github_owner=fixture-owner -d github_repo=fixture-repo -d include_release_automation=true)
assert_file_set "$base_on" true
assert_no_unresolved "$base_on" '[[' "${GIT_FLOW_ALWAYS_JINJA_FILES[@]}" "${GIT_FLOW_RELEASE_GATED_FILES[@]}"
assert_lefthook_installed "$base_on"
assert_toml_valid "$base_on"
run_rendered_hook "$base_on" pre-commit
run_rendered_hook "$base_on" pre-push
assert_hook_catches_a_real_violation "$base_on"

echo "==> rendering + verifying git-flow (include_release_automation=false)"
base_off=$(render git-flow -d github_owner=fixture-owner -d github_repo=fixture-repo -d include_release_automation=false)
assert_file_set "$base_off" false
assert_no_unresolved "$base_off" '[[' "${GIT_FLOW_ALWAYS_JINJA_FILES[@]}"
assert_lefthook_installed "$base_off"
run_rendered_hook "$base_off" pre-commit
run_rendered_hook "$base_off" pre-push

echo "==> rendering + verifying git-flow + python overlay"
overlay_dir=$(render git-flow -d github_owner=fixture-owner -d github_repo=fixture-repo)
uvx copier copy --trust --defaults --overwrite \
  -d project_name="Fixture Project" \
  -d description="A fixture project for template lint validation." \
  -d author_name="Fixture Author" \
  -d author_email="fixture@example.com" \
  python "$overlay_dir" >&2
assert_file_set "$overlay_dir" true
# README.md is overwritten by the python overlay's own README.md.jinja
# (default {{ }} delimiter), so it's excluded from the git-flow ([[ ]])
# check below and covered by the {{ }} check instead.
assert_no_unresolved "$overlay_dir" '[[' \
  .github/workflows/adr-guard.yml .github/workflows/lint.yml .github/workflows/pr-guards.yml \
  cliff.toml justfile.release .github/workflows/release-prepare.yml .github/workflows/release-publish.yml
assert_no_unresolved "$overlay_dir" '{{' \
  README.md pyproject.toml tests/test_main.py src/fixture_project/__init__.py
assert_lefthook_installed "$overlay_dir"
assert_toml_valid "$overlay_dir"
run_rendered_hook "$overlay_dir" pre-commit
run_rendered_hook "$overlay_dir" pre-push

if [ "$fail" -ne 0 ]; then
  echo "lint-templates: FAILED" >&2
  exit 1
fi
echo "lint-templates: clean"
