# 0003. Node plus pnpm toolchain for the TypeScript overlay

Date: 2026-08-18

## Status

Accepted

## Context

The repo hosts a `python/` language overlay on the git-flow base but nothing
for TypeScript, so a TS repo (first consumer: `agent-memory-server`, an MCP
server built on the official Node-first TS SDK, deployed on Cloud Run) gets
governance with no language tooling (#96). The overlay needs the same jobs
the python one covers — install/lockfile, lint/format, typecheck, test, a CI
`lang` slice — and the python overlay's design premise is a single sharp tool
per job: uv, ruff, pyright, pytest.

The tempting reading of "the uv analog" is an all-in-one like Bun. But uv
never replaces CPython — it manages it. A faithful analog keeps the runtime
and swaps the tooling around it.

## Decision

Keep **Node** (LTS, pinned in `.node-version` with an `engines.node` floor)
and pick one boring, widely-adopted tool per job:

- **pnpm** for install/lockfile/scripts, version-pinned solely by
  `package.json`'s `packageManager` field via Corepack (locally
  `corepack enable`; in CI `pnpm/action-setup` reads the same field).
- **Biome** for lint + format (the ruff analog: one binary for both).
- **`tsc --noEmit`**, strict + `noUncheckedIndexedAccess`, as the only type
  checker — vitest/tsx strip types without checking, so `include` spans
  `tests/` too.
- **vitest** for tests, **tsx** to run TS in dev (`start`).

`project_kind: app` only (`private: true`, no build); `lib` is deferred
to #97. The deploy runtime image stays the consumer's concern — the overlay
pins versions, not infrastructure.

## Alternatives considered

- **Bun single-stack** — initially chosen (runtime + install + test in one),
  then reversed: Bun replaces the Node runtime itself (JavaScriptCore, not
  V8), a bigger bet than the intended tooling swap, and breaks dev == prod
  runtime fidelity for a Node-SDK service on Cloud Run. Fails the
  boring-choice filter the rest of the template applies.
- **`bun install` + Node runtime hybrid** — keeps runtime fidelity but
  splits authority over the toolchain across two ecosystems for one fast
  install; rejected as accidental complexity.
- **npm** — no content-addressed store, slower installs, weaker workspace
  story; pnpm is the established rigorous choice with the same ubiquity.
- **eslint + prettier** instead of Biome — two configs, a plugin ecosystem
  to curate, and a formatter/linter boundary to police; Biome is one binary
  with recommended defaults, mirroring ruff's role in the python overlay.
- **jest** instead of vitest — needs a transform layer for ESM TS; vitest is
  ESM-native and config-free here (explicit imports, no globals).

## Consequences

- Everything runs on stock Node; any Node-targeted SDK behaves in dev
  exactly as in prod.
- Corepack is a load-bearing local prereq (`corepack enable` once per
  machine) — without it `pnpm` isn't on PATH and the copier post-gen tasks
  fail. Documented in the overlay READMEs.
- The Node version lives in two places by design — `.node-version` (exact)
  and `engines.node` (floor) — a Node bump must touch both.
- `pnpm-lock.yaml` is always text: reviewable, 3-way-mergeable by
  `retrofit-governance.sh`, and safe for the base `editorconfig-checker`.
- Revisit if the first consumers outgrow single-package layout (workspaces)
  or when #97 adds `project_kind: lib` with a real build.
