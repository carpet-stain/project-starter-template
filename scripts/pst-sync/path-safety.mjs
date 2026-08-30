// Path/symlink safety for manifest-derived paths (project-starter-template#157
// threads 11, 14, 18, 23). Pure lexical check plus a real-filesystem symlink
// check — no I/O beyond the local checkout, so it's real-infra-tested, not
// mocked.

import fs from "node:fs";
import path from "node:path";

/**
 * Repo-relative only: rejects absolute paths, any ".." segment, and a
 * leading "-" (so a manifest-derived path can never be parsed as a flag by
 * a filesystem command, even with a `--` guard as defense-in-depth).
 * @param {string} p
 * @returns {boolean}
 */
export function isSafeRelPath(p) {
  if (!p) return false;
  if (p.startsWith("/") || p.startsWith("-")) return false;
  return p.split("/").every((segment) => segment !== "..");
}

/**
 * Verifies a manifest `path` neither is itself a symlink nor has a
 * symlinked parent within `repoRoot` — lexical validation alone can't catch
 * this, since `cp` follows symlinks regardless of what the string looks
 * like (#157 thread 14). Treats a symlinked managed path as unsafe rather
 * than resolving through it.
 * @param {string} repoRoot - absolute path to the checkout root
 * @param {string} relPath - already lexically-safe, repo-relative path
 * @returns {{safe: boolean, reason?: string}}
 */
export function resolveManagedPath(repoRoot, relPath) {
  const segments = relPath.split("/");
  let current = repoRoot;
  for (const segment of segments) {
    current = path.join(current, segment);
    let stat;
    try {
      stat = fs.lstatSync(current);
    } catch {
      // Nothing at this depth yet (still to be created) — nothing further
      // down can be a symlink either, so the walk is done.
      break;
    }
    if (stat.isSymbolicLink()) {
      return { safe: false, reason: `${relPath} (path or a parent is a symlink — treated as diverged, never followed)` };
    }
  }
  return { safe: true };
}
