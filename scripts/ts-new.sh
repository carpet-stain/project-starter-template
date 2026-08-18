#!/usr/bin/env bash
# Greenfield scaffold: git-flow governance base, then the typescript overlay,
# into a new directory — two `copier copy` passes (copier can't merge
# templates in one). --trust is required: without it copier silently skips
# every post-gen task (pnpm install / git init / lefthook install), leaving
# no lock file and no hooks. Prereq: `corepack enable` (pnpm on PATH).
# Existing repos use retrofit-governance.sh instead.
#
# usage: scripts/ts-new.sh <new-project-dir>
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <new-project-dir>" >&2
  exit 1
fi

script_dir=$(cd "$(dirname "$(realpath "$0")")" && pwd)
template_repo_dir=$(dirname "$script_dir")

uvx copier copy --trust "$template_repo_dir/git-flow" "$1"
# --overwrite: the overlay deliberately replaces the base's README.md and
# .gitignore (docs/adding-an-overlay.md); plain copy would prompt per file.
uvx copier copy --trust --overwrite "$template_repo_dir/typescript" "$1"
