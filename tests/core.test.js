"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const { isHighConfidenceSecret } = require("../src/secrets");
const { isCode, routeContent } = require("../src/routing");
const { FrequencyStore, hashesFor, v2HashesFor, legacyKiloHash } = require("../src/frequency");
const core = require("../src/core-node");

test("redacts recognizable embedded secrets without guessing at ordinary prose and URL identifiers", () => {
  const token = "ghp_" + "a".repeat(36);
  const jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.signature";
  const pairs = [
    [`Please use ${token} for this request.`, "Please use [REDACTED] for this request."],
    ['{"password":"two words", "result":"ok"}', '{"password":"[REDACTED]", "result":"ok"}'],
    ['{"password":"$ecret123!", "result":"ok"}', '{"password":"[REDACTED]", "result":"ok"}'],
    ['Configuration:\nAZURE_API_KEY="' + "a".repeat(32) + '"\nregion=west', 'Configuration:\nAZURE_API_KEY="[REDACTED]"\nregion=west'],
    ['Configuration:\nAPI_KEY=' + "a".repeat(32) + '\nregion=west', 'Configuration:\nAPI_KEY=[REDACTED]\nregion=west'],
    [`Request:\nAuthorization: Bearer ${token}\nAccept: text/plain`, "Request:\nAuthorization: Bearer [REDACTED]\nAccept: text/plain"],
    [`The JWT is ${jwt}. Keep it private.`, "The JWT is [REDACTED]. Keep it private."],
    ["Key follows:\n-----BEGIN PRIVATE KEY-----\nYWJj\n-----END PRIVATE KEY-----\nDone", "Key follows:\n[REDACTED]\nDone"],
    ["https://example.test/?access_token=abc123&q=hello", "https://example.test/?access_token=[REDACTED]&q=hello"],
    ["See https://user:password@example.test/path", "See https://user:[REDACTED]@example.test/path"],
    ["https://calendar.google.com/calendar/ical/example/private-" + "a".repeat(32) + "/basic.ics", "https://calendar.google.com/calendar/ical/example/private-[REDACTED]/basic.ics"],
  ];
  for (const [input, expected] of pairs) {
    assert.equal(core.redactSecrets(input).text, expected);
    assert.equal(core.redactSecrets(expected).text, expected, "redaction must be idempotent");
    assert.equal(core.route({ text: input }).frequencyEligible, false);
  }
  for (const input of ["MixedCaseWords123 are ordinary prose", "Commit " + "a".repeat(40), "UUID 550e8400-e29b-41d4-a716-446655440000", "https://example.test/path/" + token + "?id=AbCd0123456789", "https://youtu.be/AbCd0123456", "https://example.test/?q=token=ordinary", "Use API_KEY=$env:API_KEY", "Use token=${ACCESS_TOKEN}"]) {
    assert.equal(core.redactSecrets(input).text, input);
    assert.equal(core.redactSecrets(input).redacted, false);
  }
});

test("mixed text is stored redacted, while standalone secrets and conceal metadata remain excluded", () => {
  const token = "ghp_" + "a".repeat(36);
  assert.equal(core.route({ text: token }).action, "ignored");
  assert.equal(core.route({ text: "API_KEY=" + "a".repeat(32) }).action, "ignored");
  assert.equal(core.route({ text: "Please use " + token, formats: ["Clipboard Viewer Ignore"] }).action, "ignored");
  const result = core.route({ text: '{"token":"' + token + '","ok":true}' });
  assert.equal(result.action, "artifacts");
  assert.equal(result.redactedText, '{"token":"[REDACTED]","ok":true}');
  assert.equal(result.frequencyEligible, false);
  assert.equal(core.route({ text: "Note " + token, formats: ["image/png"] }).redactedText, "Note [REDACTED]");
});
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

test("secret checks precede image and CopyQ metadata passthrough", () => {
  for (const formats of [["image/png"], ["application/x-copyq-owner"], ["image/png", "Clipboard Viewer Ignore"]]) {
    assert.equal(routeContent({ text: "ghp_abcdefghijklmnopqrstuvwxyz1234567890", formats, mimeOwner: "application/x-copyq-owner" }).action, "ignored");
  }
  assert.equal(routeContent({ text: "", formats: ["image/png", "Clipboard Viewer Ignore"] }).action, "ignored");
});

test("invisible formatting does not disguise a standalone key", () => {
  assert.equal(isHighConfidenceSecret("\u200bghp_abcdefghijklmnopqrstuvwxyz1234567890\u200b"), true);
  assert.equal(isHighConfidenceSecret("\u2066OpaqueSecret123456\u2069"), true);
});

test("private calendar capability URLs are secrets but public calendar and normal URLs are allowed", () => {
  assert.equal(isHighConfidenceSecret("https://calendar.google.com/calendar/ical/example%40group.calendar.google.com/private-" + "a".repeat(32) + "/basic.ics"), true);
  for (const url of ["https://calendar.google.com/calendar/ical/example/public/basic.ics", "https://calendar.google.com/calendar/embed?src=example", "https://example.test/?q=Mixed123", "https://192.168.1.2:8443", "file:///D:/images/a%20photo.jpeg"]) {
    assert.equal(isHighConfidenceSecret(url), false, url);
  }
});

test("URL routing covers standalone HTTP FTP and file links without requiring a fetch", () => {
  for (const text of ["https://example.test/feed.ics", "https://localhost:8200", "https://192.168.1.2:8443", "ftp://example.test/file", "ftps://example.test/file", "file:///D:/images/a photo.jpeg"]) {
    assert.equal(routeContent({ text }).action, "url", text);
    assert.equal(routeContent({ text }).frequencyEligible, true);
  }
  assert.equal(routeContent({ text: "https://example.test/\nA message for a friend" }).action, "default");
});

test("routes code without classifying prose as code", () => {
  assert.equal(isCode("const answer = items.map(function (item) { return item.id; });"), true);
  assert.equal(isCode("The team will return the report after the meeting."), false);
  assert.equal(routeContent({ text: "function demo() { return 1; }" }).action, "code");
});

test("classifies strong technical artifacts without diverting short technical text", () => {
  const receipt = JSON.stringify({ repository: "D:\\work\\repo", result: "published", branch: "main" });
  const powershell = "& 'D:\\tools\\publish.ps1' `\n  -Repo 'D:\\work\\repo' `\n  -Branch 'main'";
  const recoveryLog = "[21:17:14] RecoveryCapture started\nRELEASE_STAGE_FAILED: stage=RecoveryCapture\n--- backtrace ---\nentry@eval code:19";
  const transcript = "PS D:\\work> git status\nOn branch main\nnothing to commit";
  const logs = "2026-07-29T10:00:00Z INFO starting\n2026-07-29T10:00:01Z ERROR stopped";
  const stack = "Traceback (most recent call last):\n  File \"tool.py\", line 4, in <module>\nValueError: invalid";
  const diff = "diff --git a/a.js b/a.js\n@@ -1,1 +1,1 @@\n-old\n+new";
  const config = "host=localhost\nport=8080\nmode: safe";
  assert.equal(typeof core.isArtifact, "function");
  assert.equal(core.isArtifact(receipt), true);
  assert.equal(core.isArtifact(powershell), true);
  assert.equal(core.isArtifact(recoveryLog), true);
  assert.equal(core.isArtifact('["one","two"]'), true);
  assert.equal(core.isArtifact(transcript), true);
  assert.equal(core.isArtifact(logs), true);
  assert.equal(core.isArtifact(stack), true);
  assert.equal(core.isArtifact(diff), true);
  assert.equal(core.isArtifact(config), true);
  assert.equal(core.isArtifact('["one"]'), false);
  assert.equal(core.isArtifact("git status"), false);
  assert.equal(core.isArtifact("D:\\work\\repo"), false);
  assert.equal(core.isArtifact("Get-Process copyq"), false);
  assert.equal(core.isArtifact("A normal paragraph\nthat continues on another line."), false);
});

test("routing keeps primary placement separate from frequency eligibility", () => {
  assert.deepEqual(
    { ...routeContent({ text: "function demo() {}", formats: ["image/png"] }) },
    { action: "passthrough", frequencyEligible: false },
  );
  assert.deepEqual(
    { ...routeContent({ text: "https://example.test/thing" }) },
    { action: "url", frequencyEligible: true },
  );
  assert.deepEqual(
    { ...routeContent({ text: "a".repeat(5000) }) },
    { action: "big", frequencyEligible: true },
  );
  assert.deepEqual(
    { ...routeContent({ text: JSON.stringify({ repository: "repo", result: "published" }) }) },
    { action: "artifacts", frequencyEligible: true },
  );
  assert.deepEqual(
    { ...routeContent({ text: "const answer = 42;" }) },
    { action: "code", frequencyEligible: true },
  );
  assert.deepEqual(
    { ...routeContent({ text: "ordinary clipboard text" }) },
    { action: "default", frequencyEligible: true },
  );
  assert.deepEqual(
    { ...routeContent({ text: "ghp_abcdefghijklmnopqrstuvwxyz1234567890" }) },
    { action: "ignored", frequencyEligible: false },
  );
});

test("Markdown headings and quotations are not shell transcript prompts", () => {
  const markdown = "# CopyQ rendering test\n\nThis sentence contains **bold text** and *italic text*.\n\n- First test item\n- Second test item\n\n[Harmless example link](https://example.com)";
  for (const text of [markdown, "> A quoted sentence\n> Another quoted sentence", "# A heading\n\nNormal prose."]) {
    assert.equal(core.isArtifact(text), false, text);
    assert.equal(core.route({text}).action, "default", text);
  }
  for (const text of ["$ git status\nOn branch main", "root@host:~# git status\nOn branch main", "PS C:\\work> git status\nOn branch main"]) {
    assert.equal(core.isArtifact(text), true, text);
  }
});

test("frequency identity trims surrounding whitespace and promotes the sixth normalized copy", () => {
  let store = new FrequencyStore();
  const variants = ["dfosaij", "dfosaij ", " dfosaij", " dfosaij ", "dfosaij"];
  for (const text of variants) {
    const result = store.record(text);
    assert.notEqual(result.store, store);
    assert.equal(result.promote, false);
    assert.equal(result.canonicalText, "dfosaij");
    store = result.store;
  }
  const result = store.record("  dfosaij  ");
  assert.equal(result.promote, true);
  assert.equal(result.count, 6);
  assert.equal(result.key, hashesFor("dfosaij").key);
  assert.equal(Object.keys(result.store.snapshot().counters).length, 1);
});

test("v3 lazily imports normalized v2 and legacy counts without modifying either source", () => {
  const normalized = "old fixture text";
  const v2Key = v2HashesFor(normalized).key;
  const legacyKey = legacyKiloHash(normalized);
  const store = new FrequencyStore({
    v2: { version: 2, counters: { [v2Key]: { version: 2, first: "a", second: "b", count: 2, lastUsed: 1 } }, clock: 1 },
    frequent_usage_counts: { [legacyKey]: 3 },
  });
  const result = store.record("old fixture text");
  const snapshot = result.store.snapshot();
  assert.equal(result.count, 6);
  assert.equal(result.promote, true);
  assert.equal(JSON.stringify(snapshot).includes("old fixture text"), false);
  assert.equal(Object.keys(snapshot.counters).length, 1);
  assert.equal(store.v2.counters[v2Key].count, 2);
  assert.equal(store.legacy[legacyKey], 3);
});

test("dismissal resets only the active v3 count and undo adds post-dismissal copies", () => {
  let store = new FrequencyStore();
  for (let i = 0; i < 7; i += 1) store = store.record("repeat me").store;
  const key = hashesFor("repeat me").key;
  const dismissed = store.dismiss(key);
  assert.equal(dismissed.savedCount, 7);
  assert.equal(dismissed.store.snapshot().counters[key].count, 0);
  let afterDelete = dismissed.store.record(" repeat me ");
  assert.equal(afterDelete.count, 1);
  const restored = afterDelete.store.restore(key, dismissed.savedCount);
  assert.equal(restored.count, 8);
  assert.equal(restored.store.snapshot().counters[key].count, 8);
});

test("dismissal leaves a zero-count v3 tombstone even when the active counter is missing", () => {
  const key = hashesFor("legacy frequent item").key;
  const dismissed = new FrequencyStore().dismiss(key);
  assert.equal(dismissed.savedCount, 0);
  assert.equal(dismissed.store.snapshot().counters[key].count, 0);
  const next = dismissed.store.record("legacy frequent item");
  assert.equal(next.count, 1);
});

test("a dismissed Frequent item requires six fresh copies unless its deletion is undone", () => {
  let store = new FrequencyStore();
  for (let i = 0; i < 8; i += 1) store = store.record("dismiss me").store;
  const key = hashesFor("dismiss me").key;
  const dismissed = store.dismiss(key);
  store = dismissed.store;
  for (let i = 1; i <= 5; i += 1) {
    const copy = store.record(i % 2 ? " dismiss me" : "dismiss me ");
    assert.equal(copy.count, i);
    assert.equal(copy.promote, false);
    store = copy.store;
  }
  const sixth = store.record("dismiss me");
  assert.equal(sixth.count, 6);
  assert.equal(sixth.promote, true);
  const restored = sixth.store.restore(key, dismissed.savedCount);
  assert.equal(restored.count, 14);
  assert.equal(Object.keys(restored.store.snapshot().counters).length, 1);
});

test("trash expires at exactly thirty days", () => {
  assert.equal(typeof core.isTrashExpired, "function");
  const now = Date.parse("2026-07-29T12:00:00.000Z");
  assert.equal(core.isTrashExpired("2026-06-29T12:00:00.001Z", now, 30 * 86400000), false);
  assert.equal(core.isTrashExpired("2026-06-29T12:00:00.000Z", now, 30 * 86400000), true);
  assert.equal(core.isTrashExpired("not-a-date", now, 30 * 86400000), false);
});

test("frequency state keeps dual hashes and prunes least recently used counters at 4096", () => {
  let store = new FrequencyStore();
  for (let i = 0; i < 4097; i += 1) store = store.record("entry-" + i).store;
  const snapshot = store.snapshot();
  assert.equal(Object.keys(snapshot.counters).length, 4096);
  assert.equal(snapshot.counters[hashesFor("entry-0").key], undefined);
  assert.equal(snapshot.version, 3);
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
