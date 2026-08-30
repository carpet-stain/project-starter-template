// Per-entry sync decision — the pure state machine behind "Diff each managed
// file against its anchor" (#157). Split in two so the I/O shell (run.mjs)
// only fetches `theirs` when a decision actually needs it: `classifyEntry`
// decides from `base`/on-disk alone (or returns `needs-theirs` when an
// update is possible), and `finalizeUpdate` completes that decision once
// `theirs` has been fetched.

import { semverLt } from "./semver.mjs";
import { normalizeEols } from "./normalize.mjs";

/**
 * @param {object} input
 * @param {boolean} input.owned
 * @param {string} input.anchor
 * @param {string} input.target
 * @param {boolean} input.anchorTagExists
 * @param {boolean} input.onDiskExists
 * @param {string|null} input.onDiskContent
 * @param {boolean} input.baseExists
 * @param {string|null} input.baseContent
 * @returns {{kind: "owned", status: "behind"|"ahead"|"current"}
 *   | {kind: "diverged", reason: string}
 *   | {kind: "no-op"}
 *   | {kind: "needs-theirs", creating: boolean}}
 */
export function classifyEntry(input) {
  const { owned, anchor, target, anchorTagExists, onDiskExists, onDiskContent, baseExists, baseContent } = input;

  // Owned entries are never overwritten; named every run regardless of
  // version state (#157 threads 17/22 — the equal-anchor case must not
  // silently disappear from drift reporting).
  if (owned) {
    if (semverLt(anchor, target)) return { kind: "owned", status: "behind" };
    if (semverLt(target, anchor)) return { kind: "owned", status: "ahead" };
    return { kind: "owned", status: "current" };
  }

  const hasGap = semverLt(anchor, target);
  // An anchor ahead of target is anomalous (deleted release, bad manifest
  // edit) — never silently a no-op, unlike anchor == target (#157 thread 19).
  const isAhead = semverLt(target, anchor);
  const gapVerdict = () => (isAhead ? diverged("anchor is ahead of PST's current target — deleted release or invalid anchor?") : { kind: "no-op" });

  if (!anchorTagExists) {
    return diverged("anchor tag no longer exists upstream — skipped fail-closed (N4)");
  }

  if (!baseExists) {
    if (onDiskExists) {
      return diverged("added to manifest without a base at anchor, and already on disk — can't verify authorship, skipped");
    }
    return hasGap ? { kind: "needs-theirs", creating: true } : gapVerdict();
  }

  if (!onDiskExists) {
    return diverged("locally removed — skipped, won't recreate silently");
  }
  if (normalizeEols(baseContent) !== normalizeEols(onDiskContent)) {
    return diverged("local edit diverges from the anchored base — skipped");
  }
  return hasGap ? { kind: "needs-theirs", creating: false } : gapVerdict();
}

/**
 * @param {{creating: boolean, theirsExists: boolean}} input
 * @returns {{kind: "update", creating: boolean} | {kind: "diverged", reason: string}}
 */
export function finalizeUpdate({ creating, theirsExists }) {
  if (!theirsExists) {
    // Both cases used to only log an Actions-log warning and continue,
    // invisible in the sync PR body and the persistent drift issue — a real
    // silent-divergence gap against ADR-0006 (#157 thread 9).
    return creating
      ? diverged("absent at both anchor and target upstream — skipping")
      : diverged("removed from PST at target — leaving as-is, remove from the manifest if intentional");
  }
  return { kind: "update", creating };
}

function diverged(reason) {
  return { kind: "diverged", reason };
}
