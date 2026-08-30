import { test } from "node:test";
import assert from "node:assert/strict";
import { normalizeEols } from "./normalize.mjs";

test("CRLF is converted to LF", () => {
  assert.equal(normalizeEols("a\r\nb\r\n"), "a\nb\n");
});

test("a lone \\r not part of CRLF is preserved, not deleted", () => {
  // #157 thread 15: `tr -d '\r'` deleted every \r byte, so a local edit with
  // a meaningful embedded \r got misclassified as unchanged and silently
  // overwritten. A \r not immediately followed by \n must survive.
  assert.equal(normalizeEols("a\rb\n"), "a\rb\n");
});

test("mixed CRLF and lone CR: only the CRLF pair is touched", () => {
  assert.equal(normalizeEols("x\r\ny\rz\n"), "x\ny\rz\n");
});

test("trailing newlines collapse to exactly one", () => {
  assert.equal(normalizeEols("a\n\n\n"), "a\n");
  assert.equal(normalizeEols("a"), "a\n");
});

test("empty input normalizes to a single newline", () => {
  assert.equal(normalizeEols(""), "\n");
});
