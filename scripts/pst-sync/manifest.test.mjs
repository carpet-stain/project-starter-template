import { test } from "node:test";
import assert from "node:assert/strict";
import { parseOwned, findDuplicatePaths, validateManifestEntry } from "./manifest.mjs";

test("parseOwned treats absent/null owned as false", () => {
  assert.deepEqual(parseOwned({}), { ok: true, value: false });
  assert.deepEqual(parseOwned({ owned: null }), { ok: true, value: false });
});

test("parseOwned accepts a real boolean", () => {
  assert.deepEqual(parseOwned({ owned: true }), { ok: true, value: true });
  assert.deepEqual(parseOwned({ owned: false }), { ok: true, value: false });
});

test("parseOwned rejects a YAML-alias string like 'yes' (#157 thread 20)", () => {
  const result = parseOwned({ owned: "yes" });
  assert.equal(result.ok, false);
});

test("findDuplicatePaths flags a path used by 2+ entries, ignores unique ones (#157 thread 13)", () => {
  const entries = [{ path: "a" }, { path: "b" }, { path: "a" }];
  assert.deepEqual(findDuplicatePaths(entries), ["a"]);
  assert.deepEqual(findDuplicatePaths([{ path: "x" }, { path: "y" }]), []);
});

test("validateManifestEntry rejects an absolute or .. path/source (#157 thread 11)", () => {
  const base = { path: "a.txt", source: "src/a.txt", anchor: "v1.0.0" };
  assert.equal(validateManifestEntry({ ...base, path: "/etc/passwd" }).ok, false);
  assert.equal(validateManifestEntry({ ...base, source: "../../etc/passwd" }).ok, false);
});

test("validateManifestEntry rejects a non-full-semver anchor (#157 thread 4)", () => {
  const entry = { path: "a.txt", source: "src/a.txt", anchor: "v1" };
  assert.equal(validateManifestEntry(entry).ok, false);
});

test("validateManifestEntry accepts a well-formed entry", () => {
  const entry = { path: "a.txt", source: "src/a.txt", anchor: "v1.0.0", owned: true };
  assert.deepEqual(validateManifestEntry(entry), {
    ok: true,
    path: "a.txt",
    source: "src/a.txt",
    anchor: "v1.0.0",
    owned: true,
  });
});
