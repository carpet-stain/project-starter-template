import { test } from "node:test";
import assert from "node:assert/strict";
import { classifyEntry, finalizeUpdate } from "./sync.mjs";

const TARGET = "v1.2.0";

function base(overrides = {}) {
  return {
    owned: false,
    anchor: "v1.0.0",
    target: TARGET,
    anchorTagExists: true,
    onDiskExists: true,
    onDiskContent: "same\n",
    baseExists: true,
    baseContent: "same\n",
    ...overrides,
  };
}

test("clean file with a gap needs theirs (update path)", () => {
  const result = classifyEntry(base());
  assert.deepEqual(result, { kind: "needs-theirs", creating: false });
});

test("diverged file (ours != base) is reported diverged, anchor frozen", () => {
  const result = classifyEntry(base({ onDiskContent: "edited\n" }));
  assert.equal(result.kind, "diverged");
});

test("no gap and no divergence is a no-op", () => {
  const result = classifyEntry(base({ anchor: TARGET }));
  assert.deepEqual(result, { kind: "no-op" });
});

test("locally removed file with a base is diverged, not recreated", () => {
  const result = classifyEntry(base({ onDiskExists: false }));
  assert.equal(result.kind, "diverged");
});

test("no base, but already present on disk, is diverged (can't verify authorship)", () => {
  const result = classifyEntry(base({ baseExists: false, onDiskExists: true }));
  assert.equal(result.kind, "diverged");
});

test("no base, absent on disk, with a gap needs theirs (create path)", () => {
  const result = classifyEntry(base({ baseExists: false, onDiskExists: false }));
  assert.deepEqual(result, { kind: "needs-theirs", creating: true });
});

test("no base, absent on disk, no gap is a no-op", () => {
  const result = classifyEntry(base({ baseExists: false, onDiskExists: false, anchor: TARGET }));
  assert.deepEqual(result, { kind: "no-op" });
});

test("anchor tag no longer exists upstream is diverged (fail-closed, N4)", () => {
  const result = classifyEntry(base({ anchorTagExists: false }));
  assert.equal(result.kind, "diverged");
});

test("finalizeUpdate: absent at target (update path) is diverged, not a silent warning (#157 thread 9)", () => {
  const result = finalizeUpdate({ creating: false, theirsExists: false });
  assert.equal(result.kind, "diverged");
});

test("finalizeUpdate: absent at both anchor and target (create path) is diverged (#157 thread 9)", () => {
  const result = finalizeUpdate({ creating: true, theirsExists: false });
  assert.equal(result.kind, "diverged");
});

test("finalizeUpdate: theirs present completes the update", () => {
  assert.deepEqual(finalizeUpdate({ creating: false, theirsExists: true }), { kind: "update", creating: false });
  assert.deepEqual(finalizeUpdate({ creating: true, theirsExists: true }), { kind: "update", creating: true });
});

test("owned entry, anchor < target, is recorded behind", () => {
  const result = classifyEntry(base({ owned: true, anchor: "v1.0.0" }));
  assert.deepEqual(result, { kind: "owned", status: "behind" });
});

test("owned entry, anchor > target, is recorded ahead", () => {
  const result = classifyEntry(base({ owned: true, anchor: "v9.0.0" }));
  assert.deepEqual(result, { kind: "owned", status: "ahead" });
});

test("owned entry, anchor == target, is recorded current (#157 threads 17/22)", () => {
  const result = classifyEntry(base({ owned: true, anchor: TARGET }));
  assert.deepEqual(result, { kind: "owned", status: "current" });
});

test("anchor > target, unowned, matching on disk is diverged (ahead), never silently a no-op (#157 thread 19)", () => {
  const result = classifyEntry(base({ anchor: "v9.0.0", baseContent: "same\n", onDiskContent: "same\n" }));
  assert.equal(result.kind, "diverged");
});
