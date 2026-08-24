# Architecture Decision Records

Each ADR records one significant decision — what we chose, what we considered
and **rejected**, and why — as a durable, walkable file, so the design history
doesn't have to be excavated from closed issues and PRs.

## When to write one

Write an ADR when a decision is architecturally significant, cross-cutting,
long-lived, or expensive to reverse. A small, local, easily-reversed choice is a
PR description or a code comment, not an ADR — don't turn `docs/adr/` into a
dumping ground. `just adr` prints the operational version of this bar (below)
before stamping the file, so it's read at the moment it matters rather than in
a doc an author can skip.

`adr-guard.yml` enforces only the _presence_ of a record: a PR labeled
`architecture` must add or modify a file here. The judgment of whether a change
_is_ architectural stays human — it's applied by adding the label.

## Creating one

Create ADRs with the shipped tool — never hand-number or hand-format them.
`scripts/new-adr.sh` stamps the next sequential number and fills
[`templates/template.md`](templates/template.md); the `just adr` recipe wraps it:

```sh
just adr "Short decision title"       # next-numbered ADR from the template
```

It's a plain, runner-agnostic script rather than adr-tools (which has no Debian
package), so it works on any machine the repo runs on. Then edit the generated
file and fill in the sections. The **Alternatives considered** section — each
rejected option and _why_ — is the point: it's what makes the design history
walkable.

## Superseding

When a later decision replaces an earlier one, create the new ADR, then set the
old one's Status to `Superseded by NNNN` (and the new one's to `Supersedes NNNN`)
rather than editing the old ADR to match the new reality. The rejected path
staying visible is the point.

`adr-guard.yml` enforces the second half of that edit too: a new or modified
ADR whose Status says `Supersedes NNNN` must land in the same PR as an edit
to `NNNN`'s file, or CI fails — the two-file edit doesn't get to happen in
one PR and not the other.

## Amending a clause

When a later decision reverses one clause of an ADR whose overall decision
stays live, superseding is wrong — it marks the whole ADR dead. Instead the
new ADR's Status states which clause it amends, and the target gets a dated
one-line marker under its own Status, both naming the clause:

```md
## Status

Accepted. Amends 0035 (clause: <short clause name>).
```

```md
## Status

Accepted. Amended by 0037 (clause: <short clause name>).
```

`adr-guard.yml` enforces the second half of that edit too, the same way it
does for Superseding: a new or modified ADR whose Status says `Amends NNNN`
must land in the same PR as an edit to `NNNN`'s file, or CI fails. It checks
that the target is touched, not that its marker text is well-formed — the
marker itself is still a hand-written convention. This is the one amendment
style; a repo may instead carry amendments appended **inline** as new
`## Amendment — ...` sections on the target ADR (infra's history) — that
style is deprecated. Don't add new inline sections; extract existing ones to
their own amending ADRs when the target is next touched.

## Decision length

`adr-guard.yml` caps each ADR's `## Decision` section at 500 words — code
blocks and tables don't count. `Alternatives considered` and `Consequences`
are exempt entirely; they're the sections worth keeping long. If a decision
earns going over, add a visible line rather than splitting it across two
ADRs to duck the counter:

```md
## Decision

> Decision-length override: <why this decision doesn't split cleanly>
```
