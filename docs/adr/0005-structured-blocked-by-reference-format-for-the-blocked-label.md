# 0005. Structured Blocked-by reference format for the blocked label

Date: 2026-08-23

## Status

Accepted

## Context

infra#309 narrowed the `blocked` label to mean "blocked by something with no
native representation" (a third-party repo, a vendor, a pending human
decision) — issue-to-issue blocking inside the fleet is native `blocked-by`
exclusively. The label's own description already says the reason lives "in a
comment," but names no syntax. A scheduled poller (#120) that clears the
label when the referenced blocker resolves can't exist until the reference is
machine-readable, and an unparseable one must fail closed to "still
blocked," never silently clear.

One instance of the narrowed convention is already live, ad hoc, on
carpet-stain/infra#228:

```text
Blocked-by: actions/create-github-app-token#231 (non-native — third-party repo, per #309's narrowed `blocked` label convention).
```

## Decision

Formalize that live instance as the format, rather than inventing a new one:

- **Location**: an issue comment, one `Blocked-by:` line per reference.
  Multiple comments, and multiple `Blocked-by:` lines within a comment, are
  all valid — the label clears only when every parsed reference has
  resolved.
- **Syntax**: `Blocked-by: <ref>` where `<ref>` is `owner/repo#N` shorthand or
  a full `https://github.com/owner/repo/issues/N` (or `/pull/N`) URL. Free
  text may follow in parens; the poller ignores it.
- **Resolution check**: a reference "resolves" when the target issue/PR is
  closed.
- **Failure modes, all fail closed** (label stays, nothing clears silently):
  - `blocked` present, no parseable `Blocked-by:` line found anywhere on the
    issue — the poller comments once (deduped via an HTML marker) asking for
    a reference, then stays quiet on later runs until the state changes.
  - A reference parses but can't be fetched (404, rate limit, transient
    error) — logged in the workflow run only, no comment; retried next run.
  - A reference parses, fetches, and is still open — normal steady state, no
    action, no comment.

## Alternatives considered

- **Body line instead of a comment** — rejected: the label's existing
  description already commits to "reason in a comment," and the one live
  instance already uses a comment. A body-line format would contradict
  a convention already shipped.
- **Free-text reason, no required syntax** — rejected: unparseable by
  definition, which defeats the poller's reason for existing (#120).
- **Single blocker only** — rejected: costs nothing extra to support more
  than one, and nothing rules it out for a future case even though today's
  only instance (infra#228) has exactly one.
- **Comment on every unresolved poll (not just once)** — rejected: daily
  noise on a label whose steady state is "still waiting" is worse than a
  single ask-once nudge for the one real failure mode (no reference at all).

## Consequences

- The poller (#120) can be built directly against this format — the "decide
  the format before building" acceptance gate is satisfied by pointing here.
- infra#228's existing comment already conforms; no edit needed there.
- If a repo ever needs a blocker type this can't express (e.g. a condition
  with no issue/PR to point at), that's a new ADR, not a silent extension of
  this one's syntax.
