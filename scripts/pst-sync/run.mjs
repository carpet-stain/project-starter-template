#!/usr/bin/env node
// I/O shell for the sync channel's "resolve target release" + "diff each
// managed file against its anchor" steps (#157) — the parsing/validation/
// comparison logic lives in manifest.mjs/path-safety.mjs/semver.mjs/
// normalize.mjs/sync.mjs and is unit-tested there; this only does GitHub API
// calls, filesystem writes, and Actions output wiring. Can't be exercised
// outside a real Actions/GitHub run (this repo's TESTING.md layer 6), same
// posture as scripts/pr-review/run.mjs.
//
// Invoked from the consumer's checkout (`reusable-sync.yml`), but this file
// itself is fetched from PST's own tree at the exact commit the reusable
// workflow is running (checked out to $RUNNER_TEMP/pst-sync-src, outside
// $GITHUB_WORKSPACE so it never lands in the consumer's `git add -A`) — a
// naive `scripts/pst-sync/run.mjs` reference would otherwise resolve against
// the *consumer's* checkout, which doesn't have it (#146 Q2).

import fs from "node:fs";
import path from "node:path";
import { findDuplicatePaths, validateManifestEntry } from "./manifest.mjs";
import { selectTargetRelease } from "./semver.mjs";
import { resolveManagedPath } from "./path-safety.mjs";
import { classifyEntry, finalizeUpdate } from "./sync.mjs";

const { GH_TOKEN, PST_REPO, MANIFEST, RUNNER_TEMP, GITHUB_OUTPUT, GITHUB_API_URL = "https://api.github.com" } = process.env;

for (const [name, value] of Object.entries({ GH_TOKEN, PST_REPO, MANIFEST, RUNNER_TEMP, GITHUB_OUTPUT })) {
  if (!value) {
    console.error(`pst-sync: missing required env var ${name}`);
    process.exit(1);
  }
}

const repoRoot = process.cwd();

// Non-throwing: every caller needs to distinguish 200 (0) / confirmed 404 (1)
// / anything else — rate limit, 5xx, auth (2) — and never fold 1 and 2
// together (#157 threads 3/6/8).
async function githubGet(apiPath) {
  const res = await fetch(`${GITHUB_API_URL}${apiPath}`, {
    headers: { Authorization: `Bearer ${GH_TOKEN}`, Accept: "application/vnd.github+json" },
  });
  if (res.status === 200) return { status: 0, body: await res.json() };
  if (res.status === 404) return { status: 1 };
  console.error(`::error::unexpected HTTP ${res.status} calling ${apiPath}`);
  return { status: 2 };
}

async function fetchReleases() {
  const releases = [];
  for (let page = 1; ; page++) {
    const result = await githubGet(`/repos/${PST_REPO}/releases?per_page=100&page=${page}`);
    if (result.status !== 0) return result;
    releases.push(...result.body);
    if (result.body.length < 100) break;
  }
  return { status: 0, body: releases };
}

const treeCache = new Map();
// A nonexistent ref 404s at the tree endpoint — this is the fail-closed
// anchor-tag-missing signal (N4), with no separate tag-exists call needed.
async function fetchTree(ref) {
  if (treeCache.has(ref)) return treeCache.get(ref);
  const result = await githubGet(`/repos/${PST_REPO}/git/trees/${ref}?recursive=1`);
  if (result.status === 0 && result.body.truncated) {
    console.error(`::error::tree for ${ref} was truncated — recursive fetch incomplete`);
    treeCache.set(ref, { status: 2 });
    return { status: 2 };
  }
  treeCache.set(ref, result);
  return result;
}

// Fetches a managed file's content and tracked mode at a ref via the Git
// Trees + Blobs API — the Contents API this replaced doesn't carry mode, so
// a synced executable script silently lost its executable bit (#157, open
// finding #3).
async function fetchFileAt(ref, sourcePath) {
  const tree = await fetchTree(ref);
  if (tree.status !== 0) return tree;
  const entry = tree.body.tree.find((e) => e.path === sourcePath && e.type === "blob");
  if (!entry) return { status: 1 };
  const blob = await githubGet(`/repos/${PST_REPO}/git/blobs/${entry.sha}`);
  if (blob.status !== 0) return blob;
  return { status: 0, content: Buffer.from(blob.body.content, "base64").toString("utf8"), mode: entry.mode };
}

function readOnDisk(relPath) {
  const abs = path.join(repoRoot, relPath);
  try {
    return { exists: true, content: fs.readFileSync(abs, "utf8") };
  } catch {
    return { exists: false, content: null };
  }
}

function writeManaged(relPath, content, mode) {
  const abs = path.join(repoRoot, relPath);
  fs.mkdirSync(path.dirname(abs), { recursive: true });
  fs.writeFileSync(abs, content);
  // Git tree mode is a 6-digit string (e.g. "100755"); the last 3 digits are
  // the POSIX permission bits.
  fs.chmodSync(abs, parseInt(mode.slice(-3), 8));
}

function appendLine(file, line) {
  fs.appendFileSync(path.join(RUNNER_TEMP, file), `${line}\n`);
}

function setOutput(name, value) {
  fs.appendFileSync(GITHUB_OUTPUT, `${name}=${value}\n`);
}

async function main() {
  const releasesResult = await fetchReleases();
  if (releasesResult.status !== 0) {
    console.error("::error::aborting — transient failure listing releases");
    process.exit(1);
  }
  const target = selectTargetRelease(releasesResult.body);
  if (!target) {
    console.error(`::error::no non-prerelease, full-semver releases found on ${PST_REPO}`);
    process.exit(1);
  }
  setOutput("target", target);
  console.log(`resolved target: ${target}`);

  const manifestJson = JSON.parse(fs.readFileSync(path.join(RUNNER_TEMP, "manifest.json"), "utf8"));
  const rawEntries = manifestJson.files ?? [];

  const dupes = findDuplicatePaths(rawEntries);
  if (dupes.length > 0) {
    console.error(`::error::duplicate path(s) in ${MANIFEST}: ${dupes.join(", ")} — a path must appear at most once`);
    process.exit(1);
  }

  let changed = false;
  for (const filename of ["updated.txt", "diverged.txt", "owned-behind.txt", "advance.txt"]) {
    fs.writeFileSync(path.join(RUNNER_TEMP, filename), "");
  }

  for (const raw of rawEntries) {
    const validated = validateManifestEntry(raw);
    if (!validated.ok) {
      appendLine("diverged.txt", validated.reason);
      continue;
    }
    const { path: managedPath, source, anchor, owned } = validated;

    const symlinkCheck = resolveManagedPath(repoRoot, managedPath);
    if (!symlinkCheck.safe) {
      appendLine("diverged.txt", symlinkCheck.reason);
      continue;
    }

    const anchorTree = await fetchTree(anchor);
    if (anchorTree.status === 2) {
      console.error(`::error::aborting — transient failure checking anchor tag ${anchor}`);
      process.exit(1);
    }
    const anchorTagExists = anchorTree.status === 0;

    let baseExists = false;
    let baseContent = null;
    let onDisk = { exists: false, content: null };
    if (anchorTagExists) {
      const baseResult = await fetchFileAt(anchor, source);
      if (baseResult.status === 2) {
        console.error(`::error::aborting — transient failure fetching ${source}@${anchor}`);
        process.exit(1);
      }
      baseExists = baseResult.status === 0;
      baseContent = baseExists ? baseResult.content : null;
      onDisk = readOnDisk(managedPath);
    }

    const decision = classifyEntry({
      owned,
      anchor,
      target,
      anchorTagExists,
      onDiskExists: onDisk.exists,
      onDiskContent: onDisk.content,
      baseExists,
      baseContent,
    });

    if (decision.kind === "owned") {
      appendLine("owned-behind.txt", `${managedPath}: pinned at ${anchor}, PST is at ${target} (${decision.status})`);
      continue;
    }
    if (decision.kind === "diverged") {
      appendLine("diverged.txt", `${managedPath} (${decision.reason})`);
      continue;
    }
    if (decision.kind === "no-op") continue;

    // decision.kind === "needs-theirs"
    const theirsResult = await fetchFileAt(target, source);
    if (theirsResult.status === 2) {
      console.error(`::error::aborting — transient failure fetching ${source}@${target}`);
      process.exit(1);
    }
    const finalized = finalizeUpdate({ creating: decision.creating, theirsExists: theirsResult.status === 0 });
    if (finalized.kind === "diverged") {
      appendLine("diverged.txt", `${managedPath} (${finalized.reason})`);
      continue;
    }

    // Written verbatim as fetched — normalization is only for the
    // base-vs-on-disk comparison above, never applied to the bytes written
    // to disk (that would itself be a silent content mutation).
    writeManaged(managedPath, theirsResult.content, theirsResult.mode);
    appendLine("updated.txt", `${managedPath}: ${finalized.creating ? "(new)" : anchor} -> ${target}`);
    appendLine("advance.txt", managedPath);
    changed = true;
  }

  setOutput("changed", changed);
}

main().catch((err) => {
  console.error(err);
  console.error(`::error::pst-sync run.mjs failed: ${err.message}`);
  process.exit(1);
});
