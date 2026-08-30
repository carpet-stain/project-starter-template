#!/usr/bin/env bash
# Retrofit the git-flow governance templates onto an EXISTING repo,
# additively. `copier copy --overwrite` replaces colliding files and plain copy
# prompts per file, so neither is safe here; instead this generates the
# template output into a temp tree and git-merges it into the target as an
# unrelated history. git's 3-way merge is the additive semantics wanted:
# absent file -> created, existing file -> add/add conflict with both contents
# under markers for the operator to resolve, nothing ever deleted. Greenfield
# repos don't need this — use py-new.sh / ts-new.sh / `copier copy` there.
#
# Answers are derived from the repo itself (origin URL, default branch, git
# user, pyproject description) and everything else takes template defaults —
# the result is ordinary conflict-resolvable text, so wrong guesses are fixed
# in the same resolution pass, not re-prompted.
#
# usage: scripts/retrofit-governance.sh [--python|--typescript|--channel-only] [dir]
#   --python        also layer the python overlay (ci test job, ruff/pyright hooks)
#   --typescript    also layer the typescript overlay (ci test job, biome/tsc hooks)
#   --channel-only  plant just the sync channel (.pst-sync.yml + the pst-sync
#                    caller workflow) instead of the full template — for a repo
#                    that already carries governance and only needs onboarding
#                    onto the rung-2 sync channel (ADR-0006, pst#149)
#   dir             target repo (default: .)
set -euo pipefail

PYTHON=false
TYPESCRIPT=false
CHANNEL_ONLY=false
TARGET="."
for arg in "$@"; do
  case "$arg" in
    --python) PYTHON=true ;;
    --typescript) TYPESCRIPT=true ;;
    --channel-only) CHANNEL_ONLY=true ;;
    -*)
      echo "usage: $0 [--python|--typescript|--channel-only] [dir]" >&2
      exit 1
      ;;
    *) TARGET="$arg" ;;
  esac
done

if $PYTHON && $TYPESCRIPT; then
  echo "error: at most one language overlay (ADR-0020) — pass --python or --typescript, not both." >&2
  exit 1
fi
if $CHANNEL_ONLY && { $PYTHON || $TYPESCRIPT; }; then
  echo "error: --channel-only plants just the sync channel — pass it alone, without --python/--typescript." >&2
  exit 1
fi

script_dir=$(cd "$(dirname "$(realpath "$0")")" && pwd)
template_repo_dir=$(dirname "$script_dir")
cd "$TARGET"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "error: $TARGET is not a git repository." >&2
  exit 1
}
# Merging into a dirty tree tangles the operator's WIP with the retrofit —
# require a clean slate so the merge (or an abort) is the only change.
if [[ -n "$(git status --porcelain)" ]]; then
  echo "error: working tree not clean — commit or stash first." >&2
  exit 1
fi

if ! url=$(git remote get-url origin 2>/dev/null); then
  echo "error: no 'origin' remote — the base template needs the GitHub owner/repo." >&2
  exit 1
fi
# Both ssh (git@github.com:o/r.git) and https (https://github.com/o/r) forms.
owner_repo=$(echo "$url" | sed -E 's#^(git@[^:]+:|https?://[^/]+/)##; s#\.git$##')
owner=${owner_repo%%/*}
repo=${owner_repo##*/}
branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)
branch=${branch:-main}

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

if $CHANNEL_ONLY; then
  # Neither channel file is templated (no `[[ ]]` vars) — a plain copy is
  # enough, no copier render needed.
  mkdir -p "$T/.github/workflows"
  cp "$template_repo_dir/git-flow/template/.pst-sync.yml" "$T/.pst-sync.yml"
  cp "$template_repo_dir/git-flow/template/.github/workflows/pst-sync.yml" "$T/.github/workflows/pst-sync.yml"
else
  # --skip-tasks: a merge source doesn't need post-gen tasks (git init, lefthook
  # install, uv sync) — skipping keeps generated artifacts like uv.lock out of the merge.
  uvx copier copy --trust --skip-tasks --defaults \
    -d github_owner="$owner" -d github_repo="$repo" -d protected_branch="$branch" \
    "$template_repo_dir/git-flow" "$T"

  if $PYTHON; then
    desc=""
    [[ -f pyproject.toml ]] && desc=$(sed -n 's/^description = "\(.*\)"/\1/p' pyproject.toml | head -1)
    uvx copier copy --trust --skip-tasks --defaults --overwrite \
      -d project_name="$repo" -d description="$desc" \
      -d author_name="$(git config user.name)" -d author_email="$(git config user.email)" \
      "$template_repo_dir/python" "$T"
  fi

  if $TYPESCRIPT; then
    desc=""
    [[ -f package.json ]] && desc=$(sed -n 's/.*"description": *"\([^"]*\)".*/\1/p' package.json | head -1)
    uvx copier copy --trust --skip-tasks --defaults --overwrite \
      -d project_name="$repo" -d description="$desc" \
      -d author_name="$(git config user.name)" -d author_email="$(git config user.email)" \
      "$template_repo_dir/typescript" "$T"
  fi
fi

commit_msg="chore: retrofit governance templates"
next_step="lefthook install"
if $CHANNEL_ONLY; then
  commit_msg="chore: onboard onto the pst-sync channel"
  next_step="fill in the manifest's owned/anchor entries for this repo's actual files (ADR-0006, pst#148)"
fi

git -C "$T" init -q -b _retrofit-src
git -C "$T" add -A
git -C "$T" -c core.hooksPath=/dev/null commit -qm "governance template output"

# Explicit temp ref, not FETCH_HEAD (stale in a linked worktree, no-op'ing the
# merge). Forced (+): a leftover ref from a prior run would else be silently dropped.
git fetch -q "$T" +_retrofit-src:refs/heads/_retrofit-src
trap 'rm -rf "$T"; git branch -qD _retrofit-src 2>/dev/null || true' EXIT
# --no-ff: some setups pin merge.ff=only, which hard-fails a real merge.
if git merge --allow-unrelated-histories --no-ff -m "$commit_msg" _retrofit-src; then
  echo
  echo "retrofit merged clean — review the diff, then $next_step"
else
  echo
  echo "retrofit staged with conflicts (both contents kept, yours above the markers):"
  git diff --name-only --diff-filter=U | sed 's/^/  /'
  echo "resolve them, commit, then $next_step"
fi
