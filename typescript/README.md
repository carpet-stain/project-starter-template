# TypeScript project starter

Copier template for bootstrapping a Node + pnpm TypeScript project (#96).
Decisions and rationale live in ADR-0003 and on the issue; this is the
mechanism.

This is a **language overlay on the git-flow governance base** (`../git-flow`),
not a standalone template — `ts-new.sh` applies git-flow first, then layers
this on top. The layers own disjoint files (ADR-0020 in the template's source
repo): the overlay ships its own CI workflow (`test.yml`), its lefthook jobs
(`lefthook-lang.yml`, overwriting the base's empty stub), and its just verbs
(`justfile.lang`, picked up by the base justfile's `import?`). Everything the
base ships — `lint.yml`, PR guards, ADR guard, the PR template, `docs/adr/`
scaffolding, the credential pattern — comes through untouched; only
`.gitignore` and the pointer-pure `README.md` replace the base's copies.

## Use

```sh
corepack enable  # load-bearing prereq: puts pnpm on PATH for the post-gen tasks
project-starter-template/scripts/ts-new.sh <new-project-dir>
```

`ts-new.sh` applies two copier templates with `--trust`: the git-flow base,
then this overlay. `--trust` isn't optional: it's what lets the
post-generation tasks run at all (`pnpm install` generating `pnpm-lock.yaml`,
`git init`, `lefthook install`) — without it, copier silently skips every one
of those and leaves a project with no lock file and no hooks. You answer the
base's questions (owner, repo, protected branch, release automation) first,
then this overlay's (project name, package name, description, author).

The templates write no `.copier-answers` file, so there is no `copier update`
path — scaffold once, then evolve the repo directly (ADR-0021 in the
template's source repo).

## What it produces

- Single-package ESM layout (`src/`, `tests/`): Node runtime, pnpm via
  Corepack, Biome lint/format, strict `tsc --noEmit`, vitest, tsx (ADR-0003)
- `package.json`: `private: true`, `start` entry (`tsx src/index.ts` — no
  `main`; nothing is built), `packageManager` pinning the exact pnpm
  (Corepack's single authority), `engines.node` floor
- `.node-version` pinned to the Node LTS current at template-authoring time.
  The Node version lives there **and** as the `engines.node` floor — a bump
  touches both
- `tsconfig.json`: `strict`, `noUncheckedIndexedAccess`, `nodenext`;
  `include` spans `src/` and `tests/` — vitest/tsx strip types without
  checking, so tsc is the only checker. Under `nodenext`, relative imports
  need explicit `.js` suffixes (`../src/index.js` resolves the `.ts` source)
- `lefthook-lang.yml`: `biome check` + `biome format` on commit and
  `tsc --noEmit` on push, tagged `lang` — via `pnpm exec`, so tool versions
  come from `pnpm-lock.yaml`. Merged with the base's jobs by the base
  lefthook.yml's `extends`
- `.github/workflows/test.yml`: `pnpm/action-setup` (reads `packageManager`),
  `pnpm install --frozen-lockfile`, the `lang` lefthook slice, then
  `tsc --noEmit` + `vitest run`. The base's `lint.yml` runs the base slice
  separately
- `justfile.lang`: `test`, `typecheck`, `format` — the base's `import?` picks
  it up next to `lint`/`adr`

Commit `pnpm-lock.yaml` in the initial commit — CI's `--frozen-lockfile`
fails without it. `project_kind: lib` (a publishable build) is deferred
to #97.
