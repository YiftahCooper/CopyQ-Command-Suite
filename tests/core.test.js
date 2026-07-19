"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const { isHighConfidenceSecret } = require("../src/secrets");
const { isCode, routeContent } = require("../src/routing");
const { FrequencyStore, hashesFor, legacyKiloHash } = require("../src/frequency");
const { commandIdentity, mergeCommands } = require("../src/merge");
const { findDuplicates } = require("../src/inventory");
const { buildCandidate, stableStringify } = require("../src/commands");

const root = path.resolve(__dirname, "..");
const publicManifest = JSON.parse(fs.readFileSync(path.join(root, "manifest", "public-commands.json"), "utf8"));
const canonical = publicManifest.commands.filter((entry) => entry.group === "canonical");
const moonlander = publicManifest.commands.filter((entry) => entry.group === "moonlander");
const manifest = {
  managedIdentities: canonical.map((entry) => entry.identity),
  managed: canonical.map((entry) => ({ identity: entry.identity, aliases: {} })),
  protectedIdentities: moonlander.map((entry) => entry.identity),
  protectedNames: moonlander.map((entry) => entry.name),
};

test("restores conservative opaque-secret protection with structured exemptions", () => {
  assert.equal(isHighConfidenceSecret("-----BEGIN PRIVATE KEY-----\nplaceholder\n-----END PRIVATE KEY-----"), true);
  assert.equal(isHighConfidenceSecret("sk-abcdefghijklmnopqrstuvwxyz0123456789"), true);
  assert.equal(isHighConfidenceSecret("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature"), true);
  assert.equal(isHighConfidenceSecret("AKIAABCDEFGHIJKLMNOP"), true);
  assert.equal(isHighConfidenceSecret("-----BEGIN CERTIFICATE-----\npublic material\n-----END CERTIFICATE-----"), false);
  assert.equal(isHighConfidenceSecret("0123456789abcdef0123456789abcdef"), true);
  assert.equal(isHighConfidenceSecret("a".repeat(64)), true);
  assert.equal(isHighConfidenceSecret("OpaqueSecret123456"), true);
  assert.equal(isHighConfidenceSecret("550e8400-e29b-41d4-a716-446655440000"), false);
  assert.equal(isHighConfidenceSecret("https://example.test/path?query=mixed-ABC123"), false);
  assert.equal(isHighConfidenceSecret("D:\\work\\file-2026.txt"), false);
  assert.equal(isHighConfidenceSecret("/srv/copyq/release-16.0.0"), false);
  assert.equal(isHighConfidenceSecret("v16.0.0-beta.1"), false);
  assert.equal(isHighConfidenceSecret("COPYQ-1234"), false);
});

test("routes BIG only at the exact 5000-character threshold", () => {
  assert.equal(routeContent({ text: "a".repeat(4999) }).action, "default");
  assert.equal(routeContent({ text: "a".repeat(5000) }).action, "big");
});

test("routes code without classifying prose as code", () => {
  assert.equal(isCode("const answer = items.map(function (item) { return item.id; });"), true);
  assert.equal(isCode("The team will return the report after the meeting."), false);
  assert.equal(routeContent({ text: "function demo() { return 1; }" }).action, "code");
});

test("passes image and URL data through existing handlers before automatic routing", () => {
  assert.equal(routeContent({ text: "function demo() {}", formats: ["image/png"] }).action, "passthrough");
  assert.equal(routeContent({ text: "https://example.test/thing" }).action, "passthrough");
});

test("frequency keys preserve exact whitespace and promotes the sixth exact copy", () => {
  let store = new FrequencyStore();
  for (let i = 0; i < 5; i += 1) {
    const result = store.record("same text");
    assert.notEqual(result.store, store);
    assert.equal(result.promote, false);
    store = result.store;
  }
  let result = store.record("same text");
  assert.equal(result.promote, true);
  store = result.store;
  result = store.record(" same text");
  assert.equal(result.count, 1);
  assert.notEqual(hashesFor("same text").key, hashesFor(" same text").key);
});

test("lazily migrates a legacy count without retaining the copied text", () => {
  const store = new FrequencyStore({ frequent_usage_counts: { [legacyKiloHash("old fixture text")]: 5 } });
  const result = store.record("old fixture text");
  const snapshot = result.store.snapshot();
  assert.equal(result.count, 6);
  assert.equal(result.promote, true);
  assert.equal(JSON.stringify(snapshot).includes("old fixture text"), false);
  assert.equal(Object.keys(snapshot.counters).length, 1);
});

test("frequency state keeps dual hashes and prunes least recently used counters at 4096", () => {
  let store = new FrequencyStore();
  for (let i = 0; i < 4097; i += 1) store = store.record("entry-" + i).store;
  const snapshot = store.snapshot();
  assert.equal(Object.keys(snapshot.counters).length, 4096);
  assert.equal(snapshot.counters[hashesFor("entry-0").key], undefined);
  assert.equal(typeof snapshot.counters[hashesFor("entry-4096").key].first, "string");
});

test("merges only managed identities while preserving unknown objects by identity", () => {
  const unknown = { internalId: "user.unknown", nested: { preserve: true } };
  const oldManaged = { internalId: "canonical.dispatcher", cmd: "old" };
  const candidate = { internalId: "canonical.dispatcher", cmd: "new" };
  const merged = mergeCommands([unknown, oldManaged], [candidate], manifest);
  assert.equal(merged[0], unknown);
  assert.equal(merged[1], candidate);
  assert.equal(commandIdentity(candidate), "canonical.dispatcher");
});

test("refuses any candidate replacement of a protected identity", () => {
  const protectedObject = { internalId: "moonlander.smart-title", raw: { untouched: true } };
  assert.throws(() => mergeCommands([protectedObject], [{ internalId: "moonlander.smart-title" }], manifest), /protected/);
});

test("reports duplicate command names and shortcuts", () => {
  const result = findDuplicates([
    { name: "Duplicate", globalShortcuts: ["meta+shift+f"] },
    { name: "Duplicate", globalShortcuts: ["Meta+Shift+F"] },
  ]);
  assert.deepEqual(result.duplicateNames[0].indices, [0, 1]);
  assert.deepEqual(result.duplicateShortcuts[0].indices, [0, 1]);
});

test("candidate generation is deterministic and covers exactly the manifest's managed commands", () => {
  const first = stableStringify(buildCandidate());
  const second = stableStringify(buildCandidate());
  const candidate = JSON.parse(first);
  assert.equal(first, second);
  assert.deepEqual(candidate.commands.map(commandIdentity).sort(), manifest.managedIdentities.slice().sort());
  assert.equal(findDuplicates(candidate.commands).duplicateNames.length, 0);
  assert.equal(findDuplicates(candidate.commands).duplicateShortcuts.length, 0);
});

test("candidate contains the accepted utility set without Moonlander shortcuts", () => {
  const commands = buildCandidate().commands;
  const byIdentity = new Map(commands.map((entry) => [entry.internalId, entry]));
  [
    "canonical.html-sanitizer", "canonical.dispatcher", "canonical.translate-en",
    "canonical.markdown-render", "canonical.pygments-highlight", "canonical.ocr",
    "canonical.copy-json", "canonical.paste-json", "canonical.regex-search", "canonical.smart-title",
    "canonical.toggle-case", "canonical.show-frequent", "canonical.copy-and-search",
  ].forEach((identity) => assert.equal(byIdentity.has(identity), true));
  assert.deepEqual(byIdentity.get("canonical.show-frequent").globalShortcuts, ["meta+shift+f"]);
  assert.deepEqual(byIdentity.get("canonical.copy-and-search").globalShortcuts, []);
  assert.deepEqual(byIdentity.get("canonical.smart-title").globalShortcuts, []);
  assert.deepEqual(byIdentity.get("canonical.toggle-case").globalShortcuts, []);
  assert.equal(stableStringify(commands).match(/F(?:13|19|22)/i), null);
});

test("public manifest covers the exact generated canonical identities", () => {
  assert.deepEqual(
    buildCandidate().commands.map(commandIdentity).sort(),
    canonical.map((entry) => entry.identity).sort(),
  );
});
