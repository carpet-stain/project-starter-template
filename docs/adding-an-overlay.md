# Adding a language overlay

Two overlays exist today: `python/` and `typescript/`. This is the contract
the next one (Go, whatever's after) must satisfy — distilled here instead of
left to reverse-engineering from their files and scattered comments.

## File ownership — disjoint by design

An overlay and the git-flow base each own a fixed, non-overlapping set of
files (ADR-0020 in the template's source repo). An overlay ships:

- `justfile.lang` — its own verbs, picked up by the base justfile's
  `import? 'justfile.lang'`. Never add a base verb (`lint`, `adr`) here — nor
  reuse a base recipe _name_ (`format` is base-owned for markdown): just
  hard-errors on recipe redefinition across imports, so the collision breaks
  every `just` invocation in the rendered repo. Both overlays name their
  formatter verb `fmt` for exactly this reason (#99).
- `lefthook-lang.yml` — its own lefthook jobs, overwriting the base's empty
  stub. `lefthook.yml`'s `extends` picks it up either way. Never add a base
  job (`actionlint`, `markdownlint-cli2`, ...) here.
- Its own CI workflow (e.g. `python/`'s `test.yml`) — disjoint from the
  base's `lint.yml`. The base workflow never runs an overlay's checks, and
  an overlay never edits `lint.yml`.

An overlay must never touch `justfile.base`, `lefthook-base.yml`, or
`lint.yml` — those are base-owned. See `python/template/justfile.lang` and
`python/template/lefthook-lang.yml` for what a real overlay's slice looks
like.

### The two files every overlay still collides on

Copier can't merge files across two templates applied to the same directory,
so layering an overlay after the base means the overlay's copies replace the
base's for exactly two files — both collisions are deliberate and harmless,
not something to design around:

- **`.gitignore`** — the overlay's version replays the base's single
  `.envrc.local` entry (see `python/template/.gitignore`'s comment), since
  git has no include mechanism for tracked ignores. A new overlay's
  `.gitignore` must do the same: superset the base's entries, don't just
  replace them.
- **The seeded `README.md`** — the base's copy is pointer-pure front door
  text (pointing at `AGENTS.md` and `docs/adr/`), and the overlay's keeps
  that shape plus at most a few load-bearing bootstrap notes (the
  typescript one: `corepack enable`, commit the lockfile), so the overwrite
  loses nothing.

## `copier.yml` conventions

- `_subdirectory: template` — the actual template source lives one level
  down, so a consumer's `git clone` of this repo isn't itself a valid copier
  source.
- Question naming: plain, human-meaningful names (`project_name`,
  `package_name`) — derive a default from another answer with Jinja where it
  saves a redundant prompt (`python/copier.yml`'s `package_name` default
  slugifies `project_name`).
- `_tasks` — a **string** task runs via `sh -c "<script>"`, not the script's
  own shebang: `/bin/sh` is dash on Linux (no `pipefail`) even if the string
  starts with `#!/usr/bin/env bash` — that line is just a comment to `sh`,
  never a re-exec (#37). If a task needs bash (`pipefail`, `<<<`, etc.), use
  copier's **array** form instead — `[bash, -c, "<script>"]` — which copier
  executes directly with no shell in between, so it doesn't depend on what
  `/bin/sh` happens to be. See `python/copier.yml`'s `_tasks` entry for a real
  one (`uv python pin`, `uv sync`, `git init`, `lefthook install`).

## Tagging

Tag every lefthook job you ship `lang` (mirroring the base's `base` tag).
That's what your overlay's CI workflow scopes to
(`lefthook run pre-commit --all-files --tag lang`) — disjoint from the
base's `lint.yml`, which scopes to `--tag base`. Locally, unfiltered, every
layer's jobs run together on every commit/push.

## One overlay at a time

A generated repo is the git-flow base plus **at most one** language overlay
— never more (ADR-0020 in the template's source repo). Don't design an
overlay assuming another overlay might be layered alongside it; that
combination isn't supported.

## Worked examples

`python/` is the original reference: `python/copier.yml` (questions, the
`_tasks` array form above), `python/template/justfile.lang`,
`python/template/lefthook-lang.yml`, `python/template/.github/workflows/test.yml`,
and `python/template/.gitignore`. `typescript/` is the second instance of the
same contract (Node + pnpm toolchain — ADR-0003). Each overlay's own README
documents its questions and output; this guide covers the contract every
overlay shares — read them together when starting a new one.
