// `.pst-sync.yml` schema validation — `path`/`source`/`anchor`/`owned` per
// entry (#157). YAML->JSON decoding stays in the workflow YAML (`yq -o=json`,
// already an established ambient-tool dependency); this operates on the
// already-parsed entry objects.

import { isSafeRelPath } from "./path-safety.mjs";
import { isFullSemver } from "./semver.mjs";

/**
 * A YAML alias like `yes` parses as the string "yes", not a boolean —
 * silently defaulting that to unowned risks overwriting a file the
 * maintainer intended to protect (#157 thread 20).
 * @param {{owned?: unknown}} entry
 * @returns {{ok: true, value: boolean} | {ok: false, reason: string}}
 */
export function parseOwned(entry) {
  if (entry.owned === undefined || entry.owned === null) return { ok: true, value: false };
  if (typeof entry.owned === "boolean") return { ok: true, value: entry.owned };
  return { ok: false, reason: `owned: ${JSON.stringify(entry.owned)} isn't a boolean — skipped, fix the manifest` };
}

/**
 * `advance_anchor` selects by path alone — a duplicate path would let one
 * entry's clean sync silently advance another entry's frozen anchor (#157
 * thread 13).
 * @param {{path: string}[]} entries
 * @returns {string[]} paths that appear more than once
 */
export function findDuplicatePaths(entries) {
  const counts = new Map();
  for (const { path } of entries) counts.set(path, (counts.get(path) ?? 0) + 1);
  return [...counts.entries()].filter(([, count]) => count > 1).map(([path]) => path);
}

/**
 * @param {{path: string, source: string, anchor: string, owned?: unknown}} entry
 * @returns {{ok: true, path: string, source: string, anchor: string, owned: boolean}
 *   | {ok: false, path: string, reason: string}}
 */
export function validateManifestEntry(entry) {
  const { path, source, anchor } = entry;
  if (!isSafeRelPath(path) || !isSafeRelPath(source)) {
    return { ok: false, path, reason: `${path} (path or source isn't a safe repo-relative path — skipped)` };
  }
  if (!isFullSemver(anchor)) {
    return { ok: false, path, reason: `${path} (anchor '${anchor}' isn't an immutable full-semver tag — skipped, needs a real PST release tag)` };
  }
  const owned = parseOwned(entry);
  if (!owned.ok) {
    return { ok: false, path, reason: `${path} (${owned.reason})` };
  }
  return { ok: true, path, source, anchor, owned: owned.value };
}
