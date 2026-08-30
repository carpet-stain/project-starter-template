import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { isSafeRelPath, resolveManagedPath } from "./path-safety.mjs";

test("isSafeRelPath accepts a normal nested relative path", () => {
  assert.equal(isSafeRelPath("a/b/c.txt"), true);
});

test("isSafeRelPath rejects empty, absolute, leading -, and any .. segment", () => {
  assert.equal(isSafeRelPath(""), false);
  assert.equal(isSafeRelPath("/etc/passwd"), false);
  assert.equal(isSafeRelPath("--target-directory=.."), false);
  assert.equal(isSafeRelPath("../../etc/passwd"), false);
  assert.equal(isSafeRelPath("a/../b"), false);
});

test("isSafeRelPath does not false-positive on '..' as a mere substring", () => {
  assert.equal(isSafeRelPath("a..b/c"), true);
  assert.equal(isSafeRelPath("weird..name.txt"), true);
});

// Regression for thread 18 (bash's unquoted `for part in $p` word-splitting
// and glob-expanding manifest paths after IFS splitting). JS array iteration
// over a String.split() result never globs or word-splits, but the point of
// the test is to pin that a path with glob metacharacters or embedded
// whitespace/`#` is validated as the literal string it is, never expanded or
// misparsed.
test("isSafeRelPath treats glob metacharacters and special chars as literal path text", () => {
  assert.equal(isSafeRelPath("a/b*c/[x].txt"), true);
  assert.equal(isSafeRelPath("a dir/file#1.txt"), true);
  assert.equal(isSafeRelPath("a/b?c"), true);
});

test("resolveManagedPath rejects when the managed path itself is a symlink", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "pst-sync-"));
  const real = path.join(root, "real.txt");
  fs.writeFileSync(real, "content");
  const link = path.join(root, "link.txt");
  fs.symlinkSync(real, link);
  const result = resolveManagedPath(root, "link.txt");
  assert.equal(result.safe, false);
  fs.rmSync(root, { recursive: true, force: true });
});

test("resolveManagedPath rejects when a parent directory is a symlink", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "pst-sync-"));
  const realDir = path.join(root, "real-dir");
  fs.mkdirSync(realDir);
  fs.writeFileSync(path.join(realDir, "file.txt"), "content");
  const linkDir = path.join(root, "link-dir");
  fs.symlinkSync(realDir, linkDir);
  const result = resolveManagedPath(root, "link-dir/file.txt");
  assert.equal(result.safe, false);
  fs.rmSync(root, { recursive: true, force: true });
});

test("resolveManagedPath accepts a normal nested non-symlinked path (existing)", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "pst-sync-"));
  fs.mkdirSync(path.join(root, "nested"));
  fs.writeFileSync(path.join(root, "nested", "file.txt"), "content");
  const result = resolveManagedPath(root, "nested/file.txt");
  assert.equal(result.safe, true);
  fs.rmSync(root, { recursive: true, force: true });
});

test("resolveManagedPath accepts a normal nested path that doesn't exist yet", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "pst-sync-"));
  const result = resolveManagedPath(root, "not/yet/created.txt");
  assert.equal(result.safe, true);
  fs.rmSync(root, { recursive: true, force: true });
});
