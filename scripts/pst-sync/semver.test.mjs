import { test } from "node:test";
import assert from "node:assert/strict";
import { isFullSemver, semverLt, selectTargetRelease } from "./semver.mjs";

test("isFullSemver accepts vX.Y.Z, rejects everything else", () => {
  assert.equal(isFullSemver("v1.2.3"), true);
  assert.equal(isFullSemver("v1"), false);
  assert.equal(isFullSemver("v1.2"), false);
  assert.equal(isFullSemver("1.2.3"), false);
  assert.equal(isFullSemver("v1.2.3-rc1"), false);
});

test("semverLt compares numerically, not lexicographically", () => {
  assert.equal(semverLt("v1.2.3", "v1.10.0"), true);
  assert.equal(semverLt("v1.10.0", "v1.2.3"), false);
  assert.equal(semverLt("v1.0.0", "v1.0.0"), false);
});

test("selectTargetRelease picks the highest full-semver non-prerelease tag", () => {
  const releases = [
    { tag_name: "v1.0.0", prerelease: false },
    { tag_name: "v1.2.0", prerelease: false },
    { tag_name: "v2.0.0-rc1", prerelease: true },
  ];
  assert.equal(selectTargetRelease(releases), "v1.2.0");
});

test("selectTargetRelease filters a non-semver stable tag before comparing (#157 thread 16)", () => {
  // A stray non-semver stable release (e.g. a hand-pushed "latest" tag) must
  // never be able to sort above valid releases and abort every run.
  const releases = [
    { tag_name: "v1.0.0", prerelease: false },
    { tag_name: "zzz-not-semver", prerelease: false },
    { tag_name: "v1.5.0", prerelease: false },
  ];
  assert.equal(selectTargetRelease(releases), "v1.5.0");
});

test("selectTargetRelease returns null when no valid release exists", () => {
  assert.equal(selectTargetRelease([]), null);
  assert.equal(selectTargetRelease([{ tag_name: "v1.0.0", prerelease: true }]), null);
  assert.equal(selectTargetRelease([{ tag_name: "not-semver", prerelease: false }]), null);
});
