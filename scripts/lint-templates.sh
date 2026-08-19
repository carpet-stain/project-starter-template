#!/usr/bin/env bash
# Render-then-verify for the copier templates (git-flow base, git-flow plus
# python/typescript overlay) hosted here — see dotfiles#310 (original) and
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

# Unset before any copier invocation — inherited from lefthook's pre-push hook,
# these make copier's own `git ls-remote` on the template source fail.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_PREFIX 2>/dev/null || true

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

fail=0

# j2lint_pass F... -> raw jinja check; skips cliff.toml.jinja and
# release-*/pr-guards.yml.jinja, whose embedded Tera/`${{ }}` syntax j2lint misreads.
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
mapfile -d '' all_jinja < <(find git-flow/template python/template typescript/template -name "*.jinja" -print0)
j2lint_pass "${all_jinja[@]}"

# check_payload_action_pins -> actions pinned in both the payload and this
# repo's own workflows must agree on the major — offline, no "latest" (#89).
check_payload_action_pins() {
  local entry action major files
  declare -A own_pin
  while IFS= read -r entry; do
    action=${entry%@v*}
    major=${entry##*@v}
    own_pin[$action]=${major%%.*}
  done < <(grep -rhoE 'uses:[[:space:]]*[^[:space:]]+@v[0-9.]+' .github/workflows | sed -E 's/uses:[[:space:]]*//' | sort -u)
  # Unique (action, major) pairs, not one entry per action: a payload mixing
  # two majors of the same action must surface both, not last-wins one.
  while read -r action major; do
    # setup-uv excluded: lint-templates.yml runs it as harness tooling and
    # lags latest, while the payload tracks latest major (#88).
    [ "$action" = "astral-sh/setup-uv" ] && continue
    [ -n "${own_pin[$action]:-}" ] || continue
    if [ "$major" != "${own_pin[$action]}" ]; then
      files=$(grep -rlE "uses:[[:space:]]*$action@v$major" git-flow/template python/template typescript/template | paste -sd ' ' -)
      echo "payload pins $action@v$major but this repo's own workflows pin @v${own_pin[$action]}: $files" >&2
      fail=1
    fi
  done < <(grep -rhoE 'uses:[[:space:]]*[^[:space:]]+@v[0-9.]+' git-flow/template python/template typescript/template |
    sed -E 's/uses:[[:space:]]*//; s/@v([0-9]+)[0-9.]*/ \1/' | sort -u)
}

echo "==> payload action pins vs own workflows"
check_payload_action_pins

# Explicit list, not `find template -name '*.jinja'`: {% if %}-wrapped
# filenames need that conditional evaluated to know their rendered path.
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

# assert_file_set <dir> <release_automation: true|false>  ->  gated files
# land per the answer; asserts no stray unrendered filename survived.
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

# assert_no_unresolved <dir> <delimiter> <file...> -> scoped to the given
# files, not a whole-tree grep: avoids false positives on bash `[[ ]]`/TOML `[[table]]`.
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

# assert_lefthook_installed <dir> -> confirms post-gen's `lefthook install`
# landed a hook explicitly, rather than leaning on render()'s implicit abort.
assert_lefthook_installed() {
  local dir=$1
  [ -x "$dir/.git/hooks/pre-commit" ] || {
    echo "lefthook install did not land an executable pre-commit hook in $dir" >&2
    fail=1
  }
}

# assert_toml_valid <dir> -> lint only, not `taplo fmt --check`: rendered
# line length depends on the answers, so fmt-check would flag the answers, not a template defect.
assert_toml_valid() {
  local dir=$1
  local toml_files
  mapfile -t toml_files < <(cd "$dir" && git ls-files '*.toml')
  [ "${#toml_files[@]}" -gt 0 ] || return 0
  (cd "$dir" && taplo lint "${toml_files[@]}") || fail=1
}

# assert_json_valid <dir> <file...> -> structural parse only, the JSON
# sibling of assert_toml_valid (tsconfig.json is deliberately comment-free).
assert_json_valid() {
  local dir=$1 f
  shift
  for f in "$@"; do
    node -e 'JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"))' "$dir/$f" || {
      echo "invalid JSON: $dir/$f" >&2
      fail=1
    }
  done
}

# run_rendered_hook <dir> <pre-commit|pre-push> -> runs the rendered repo's
# own lefthook slice unscoped, so base + language-overlay jobs both run.
run_rendered_hook() {
  local dir=$1 hook=$2
  git -C "$dir" add -A
  (cd "$dir" && lefthook run "$hook" --all-files --no-tty) || fail=1
}

# assert_hook_catches_a_real_violation <dir> -> seeds a violation to prove
# the checks actually check, not just that clean fixture input passes.
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
# README.md is excluded from the git-flow ([[ ]]) check below: the python
# overlay's README.md.jinja overwrites it using the default {{ }} delimiter.
assert_no_unresolved "$overlay_dir" '[[' \
  .github/workflows/adr-guard.yml .github/workflows/lint.yml .github/workflows/pr-guards.yml \
  cliff.toml justfile.release .github/workflows/release-prepare.yml .github/workflows/release-publish.yml
assert_no_unresolved "$overlay_dir" '{{' \
  README.md pyproject.toml tests/test_main.py src/fixture_project/__init__.py
assert_lefthook_installed "$overlay_dir"
assert_toml_valid "$overlay_dir"
# just parses base + overlay justfiles — catches an overlay verb colliding
# with a base recipe (the class #99 shipped; just hard-errors on redefinition).
(cd "$overlay_dir" && just --list >/dev/null) || fail=1
run_rendered_hook "$overlay_dir" pre-commit
run_rendered_hook "$overlay_dir" pre-push

echo "==> rendering + verifying git-flow + typescript overlay"
ts_dir=$(render git-flow -d github_owner=fixture-owner -d github_repo=fixture-repo)
uvx copier copy --trust --defaults --overwrite \
  -d project_name="Fixture Project" \
  -d description="A fixture project for template lint validation." \
  -d author_name="Fixture Author" \
  -d author_email="fixture@example.com" \
  typescript "$ts_dir" >&2
assert_file_set "$ts_dir" true
assert_no_unresolved "$ts_dir" '[[' \
  .github/workflows/adr-guard.yml .github/workflows/lint.yml .github/workflows/pr-guards.yml \
  cliff.toml justfile.release .github/workflows/release-prepare.yml .github/workflows/release-publish.yml
assert_no_unresolved "$ts_dir" '{{' README.md package.json src/index.ts
assert_json_valid "$ts_dir" package.json tsconfig.json biome.json
# Default project_kind renders the app shape — private, no build config.
grep -q '"private": true' "$ts_dir/package.json" || {
  echo "typescript app render lost private: true" >&2
  fail=1
}
[ -e "$ts_dir/tsconfig.build.json" ] && {
  echo "tsconfig.build.json present in an app render" >&2
  fail=1
}
# Files test.yml reads at runtime but nothing below executes — a dotfile a
# contributor's global gitignore swallowed shipped as a missing file once (#100).
for f in .node-version pnpm-lock.yaml; do
  [ -f "$ts_dir/$f" ] || {
    echo "typescript render is missing $f" >&2
    fail=1
  }
done
assert_lefthook_installed "$ts_dir"
assert_toml_valid "$ts_dir"
# just parses all three justfiles here — catches an overlay verb colliding
# with a base one (just hard-errors on recipe redefinition).
(cd "$ts_dir" && just --list >/dev/null) || fail=1
run_rendered_hook "$ts_dir" pre-commit
run_rendered_hook "$ts_dir" pre-push
# Inline typecheck + test; biome is a lang-tagged lefthook job already run above.
(cd "$ts_dir" && pnpm exec tsc --noEmit) || fail=1
(cd "$ts_dir" && pnpm run test) || fail=1

echo "==> rendering + verifying git-flow + typescript overlay (project_kind=lib)"
ts_lib_dir=$(render git-flow -d github_owner=fixture-owner -d github_repo=fixture-repo)
uvx copier copy --trust --defaults --overwrite \
  -d project_name="Fixture Project" \
  -d description="A fixture project for template lint validation." \
  -d author_name="Fixture Author" \
  -d author_email="fixture@example.com" \
  -d project_kind=lib \
  typescript "$ts_lib_dir" >&2
assert_file_set "$ts_lib_dir" true
assert_no_unresolved "$ts_lib_dir" '{{' README.md package.json src/index.ts
assert_json_valid "$ts_lib_dir" package.json tsconfig.json tsconfig.build.json biome.json
# Publishable shape: not private, exports present, the declaration build
# emits — tsc --noEmit never exercises emit (TS2742 class), so build for real.
grep -q '"private"' "$ts_lib_dir/package.json" && {
  echo "lib render still carries private" >&2
  fail=1
}
grep -q '"exports"' "$ts_lib_dir/package.json" || {
  echo "lib render missing exports" >&2
  fail=1
}
assert_lefthook_installed "$ts_lib_dir"
(cd "$ts_lib_dir" && just --list >/dev/null) || fail=1
(cd "$ts_lib_dir" && pnpm run build) || fail=1
for f in dist/index.js dist/index.d.ts; do
  [ -f "$ts_lib_dir/$f" ] || {
    echo "lib build did not emit $f" >&2
    fail=1
  }
done
run_rendered_hook "$ts_lib_dir" pre-commit
run_rendered_hook "$ts_lib_dir" pre-push
(cd "$ts_lib_dir" && pnpm run test) || fail=1

if [ "$fail" -ne 0 ]; then
  echo "lint-templates: FAILED" >&2
  exit 1
fi
echo "lint-templates: clean"
