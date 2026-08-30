// Semver comparison and target-release selection (#157: "the plan does not
// require a pinned tool version" applies to the shell too — this is the
// exact logic the shell's `sort -V` was standing in for). release-publish.yml
// only ever cuts a `vX.Y.Z` tag, but this never trusts that blindly — every
// anchor and the resolved target are validated against the immutable shape
// before use (#157 thread 4).

const FULL_SEMVER = /^v(\d+)\.(\d+)\.(\d+)$/;

/** @param {string} tag @returns {boolean} */
export function isFullSemver(tag) {
  return FULL_SEMVER.test(tag);
}

function parts(tag) {
  return tag
    .slice(1)
    .split(".")
    .map((n) => Number(n));
}

/** Numeric compare, not lexicographic (`v1.2.3` < `v1.10.0`). Assumes both
 * tags already passed {@link isFullSemver}. @returns {number} */
export function semverCompare(a, b) {
  const pa = parts(a);
  const pb = parts(b);
  for (let i = 0; i < 3; i++) {
    if (pa[i] !== pb[i]) return pa[i] - pb[i];
  }
  return 0;
}

/** @param {string} a @param {string} b @returns {boolean} */
export function semverLt(a, b) {
  return semverCompare(a, b) < 0;
}

/**
 * Never `releases/latest` (newest-by-created_at) — a back-patch would strand
 * consumers below true-latest. Filters to non-prerelease AND the immutable
 * full-semver shape *before* comparing (#157 thread 16 — filtering only
 * after `sort -V` lets one stray non-semver stable tag sort highest and
 * brick every run even when valid releases exist).
 * @param {{tag_name: string, prerelease: boolean}[]} releases
 * @returns {string|null}
 */
export function selectTargetRelease(releases) {
  const candidates = releases.filter((r) => r.prerelease === false && isFullSemver(r.tag_name));
  if (candidates.length === 0) return null;
  return candidates.reduce((max, r) => (semverCompare(r.tag_name, max.tag_name) > 0 ? r : max)).tag_name;
}
