"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const sharedSource = fs.readFileSync(path.join(root, "src", "shared-core.js"), "utf8");
const Core = vm.runInNewContext(sharedSource + "\nCopyQCore;", {});
const { buildCandidate } = require("../src/commands");

function dispatcher() { return buildCandidate().commands.find((entry) => entry.internalId === "canonical.dispatcher"); }

test("the generated dispatcher embeds the exact ES5 core that Node executes", () => {
  assert.equal(dispatcher().cmd.includes(sharedSource), true);
  assert.equal(typeof Core.route, "function");
  assert.equal(/(?:^|[;{}]\s*)(?:const|let)\s/.test(sharedSource), false);
});

test("dispatcher gives a content-free notification before ignoring a secret", () => {
  const command = dispatcher().cmd;
  const notice = "notification('.id', 'secret-ignore', '.title', 'Ignoring secret in the clipboard', '.message', 'SECRET_IGNORED')";
  assert.equal(command.includes(notice), true);
  assert.equal(command.indexOf(notice) < command.indexOf("ignore(); abort();"), true);
  assert.equal(notice.includes("text"), false);
});

test("shared core trims only for secret detection and keeps exact text for v2 frequency", () => {
  assert.equal(Core.isHighConfidenceSecret("  DB_PASSWORD=abcdefghijklmnopqrstuvwxyz012345  ", []), true);
  assert.equal(Core.isHighConfidenceSecret("glpat-abcdefghijklmnopqrstuvwxyz012345", []), true);
  assert.equal(Core.isHighConfidenceSecret("npm_abcdefghijklmnopqrstuvwxyz012345", []), true);
  assert.equal(Core.isHighConfidenceSecret("pypi-abcdefghijklmnopqrstuvwxyz012345", []), true);
  assert.equal(Core.isHighConfidenceSecret("ordinary-ID-ABC123", []), true);
  assert.equal(Core.isHighConfidenceSecret("https://example.test/path", []), false);
  assert.equal(Core.isHighConfidenceSecret("0123456789abcdef0123456789abcdef", []), true);
  assert.equal(Core.isHighConfidenceSecret("abcdef0123456789".repeat(4), []), true);
  assert.equal(Core.isHighConfidenceSecret("OpaqueSecret123456", []), true);
  assert.equal(Core.isHighConfidenceSecret("550e8400-e29b-41d4-a716-446655440000", []), false);
  assert.equal(Core.isHighConfidenceSecret("D:\\work\\CopyQ-16.0.0", []), false);
  assert.equal(Core.isHighConfidenceSecret("/srv/copyq/CopyQ-16.0.0", []), false);
  assert.equal(Core.isHighConfidenceSecret("v16.0.0-beta.1", []), false);
  assert.equal(Core.isHighConfidenceSecret("COPYQ-1234", []), false);
  assert.equal(Core.isHighConfidenceSecret("anything", ["Clipboard Viewer Ignore"]), true);
  assert.equal(Core.isHighConfidenceSecret("anything", ["x-kde-passwordManagerHint"]), true);
  assert.equal(Core.isHighConfidenceSecret("anything", ["nspasteboard concealed"]), true);
  const legacy = {}; legacy[Core.legacyKiloHash("same")] = 5;
  const result = Core.recordFrequency({ version: 2, counters: {}, clock: 0 }, legacy, " same ");
  assert.equal(result.result.count, 6);
  assert.equal(result.state.counters[Core.hashesFor(" same ").key].count, 6);
  const exactNext = Core.recordFrequency(result.state, result.legacy, "same");
  assert.equal(exactNext.result.count, 1);
  assert.equal(JSON.stringify(exactNext).includes(" same "), false);
});

test("shared routing preserves owner-window metadata but ignores only actual owner/hidden/secret metadata", () => {
  const ownedWindow = Core.route({ text: "ordinary", formats: ["application/x-copyq-owner-window-title"], state: { version: 2, counters: {}, clock: 0 }, legacy: {} });
  assert.equal(ownedWindow.action, "default");
  assert.equal(ownedWindow.frequency.result.count, 1);
  assert.equal(Core.route({ text: "ordinary", formats: ["application/x-copyq-owner"], mimeOwner: "application/x-copyq-owner" }).action, "passthrough");
  assert.equal(Core.route({ text: "ordinary", formats: ["application/x-copyq-hidden"], mimeHidden: "application/x-copyq-hidden" }).action, "passthrough");
  assert.equal(Core.route({ text: "ordinary", formats: ["mimeSecret"] }).action, "ignored");
});

test("shared utility helpers expose concrete semantics", () => {
  assert.equal(Core.isMarkdown("# Heading"), true);
  assert.equal(Core.isMarkdown("ordinary prose"), false);
  assert.equal(Core.titleCase("the id and tv guide"), "The ID and TV Guide");
  assert.equal(Core.validateJsonImport("not json").ok, false);
  assert.equal(Core.validateJsonImport('{"copyq_items":[]}').ok, true);
  assert.equal(Core.validateJsonImport('{"copyq_items":[{"text/plain":{"base64":42}}]}').reason, "JSON_SHAPE_INVALID");
  assert.equal(Core.validateJsonImport('{"copyq_items":["not-an-item"]}').reason, "JSON_SHAPE_INVALID");
  assert.equal(Core.validateRegex("[").ok, false);
  assert.equal(Core.validateRegex("ok").ok, true);
  const dependency = Core.runDependency(function () { return { exit_code: 1 }; }, []);
  assert.equal(dependency.ok, false);
  assert.equal(Core.isCode("const value = 1;"), true);
  assert.equal(Core.isCode("let value = 1;"), true);
  assert.equal(
    Core.sanitizeHtml('<p style="color:red;font-size:12px;background-color:#fff">Hello</p>'),
    '<p style="font-size:12px">Hello</p>',
  );
  assert.equal(Core.sanitizeHtml('<font color="red" face="Arial">Hello</font>'), '<font face="Arial">Hello</font>');
  assert.equal(Core.toggleCase("Mixed Case"), "MIXED CASE");
  assert.equal(Core.toggleCase("UPPER"), "upper");
});

test("candidate usability fields remain explicit", () => {
  const commands = buildCandidate().commands;
  const byId = new Map(commands.map((entry) => [entry.internalId, entry]));
  assert.equal(byId.get("canonical.ocr").globalShortcuts[0], "meta+ctrl+t");
  assert.equal(byId.get("canonical.show-frequent").globalShortcuts[0], "meta+shift+f");
  assert.deepEqual(byId.get("canonical.copy-and-search").globalShortcuts, []);
  assert.equal(byId.get("canonical.dispatcher").inMenu, false);
  assert.equal(byId.get("canonical.translate-en").inMenu, true);
  commands.forEach((entry) => assert.equal(entry.display, false, entry.internalId));
  assert.equal(commands.length, 13);
});

test("generated commands use real conceal MIME values and safe operational command bodies", () => {
  assert.equal(Core.isHighConfidenceSecret("visible", ["application/x-copyq-secret"]), true);
  assert.equal(Core.isHighConfidenceSecret("visible", ["org.nspasteboard.ConcealedType"]), true);
  const commands = buildCandidate().commands;
  const byId = new Map(commands.map((entry) => [entry.internalId, entry]));
  const dispatch = byId.get("canonical.dispatcher").cmd;
  assert.equal(dispatch.includes("application\\/x-copyq-secret"), true);
  assert.equal(dispatch.includes("org\\.nspasteboard\\.concealedtype"), true);
  const search = byId.get("canonical.regex-search").cmd;
  assert.match(search, /var names = tab\(\)/);
  assert.doesNotMatch(search, /var names = tabs\.split/);
  assert.match(search, /removeTab\('Search'\)/);
  assert.match(search, /if \(names\[t\] === 'Search'\) continue/);
  const frequency = dispatch;
  assert.match(frequency, /selectedTab\(\)/);
  assert.match(frequency, /ignore\(\); tab\(originalTab\); abort\(\)/);
  const ocr = byId.get("canonical.ocr").cmd;
  assert.match(ocr, /selectedItemsData\(\)/);
  assert.doesNotMatch(ocr, /screenshotSelect|dialog\(/);
  assert.match(ocr, /env\('ProgramFiles'\)/);
  assert.match(ocr, /Tesseract-OCR/);
  assert.match(ocr, /'eng\+heb'/);
  assert.doesNotMatch(ocr, /\bgm\b/i);
  const sanitizer = byId.get("canonical.html-sanitizer").cmd;
  assert.match(sanitizer, /CopyQCore\.sanitizeHtml/);
  assert.doesNotMatch(sanitizer, /replace\(\/color\\s\*:\/g, 'xxx:'\)/);
  const toggle = byId.get("canonical.toggle-case").cmd;
  assert.match(toggle, /CopyQCore\.toggleCase/);
  const frequent = byId.get("canonical.show-frequent").cmd;
  assert.match(frequent, /menu\('Frequent'\)/);
  assert.doesNotMatch(frequent, /copyq menu/);
});
