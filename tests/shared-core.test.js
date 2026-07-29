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
function runtimeOnly(command) { return command.slice(command.lastIndexOf("}());") + 5); }

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

test("shared core trims frequency identity while preserving conservative secret detection", () => {
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
  const legacy = {}; legacy[Core.legacyKiloHash("same")] = 2;
  const v2 = { version: 2, counters: {}, clock: 0 };
  v2.counters[Core.v2HashesFor("same").key] = { count: 3, lastUsed: 1 };
  const result = Core.recordFrequency({ version: 3, counters: {}, clock: 0 }, v2, legacy, " same ");
  assert.equal(result.result.count, 6);
  assert.equal(result.result.canonicalText, "same");
  assert.equal(result.state.counters[Core.hashesFor("same").key].count, 6);
  const exactNext = Core.recordFrequency(result.state, v2, legacy, "same ");
  assert.equal(exactNext.result.count, 7);
  assert.equal(JSON.stringify(exactNext.state).includes("same"), false);
  assert.equal(v2.counters[Core.v2HashesFor("same").key].count, 3);
  assert.equal(legacy[Core.legacyKiloHash("same")], 2);
});

test("shared routing preserves owner-window metadata but ignores only actual owner/hidden/secret metadata", () => {
  const ownedWindow = Core.route({ text: "ordinary", formats: ["application/x-copyq-owner-window-title"], state: { version: 2, counters: {}, clock: 0 }, legacy: {} });
  assert.equal(ownedWindow.action, "default");
  assert.equal(ownedWindow.frequencyEligible, true);
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
  assert.equal(byId.get("canonical.undoable-delete-listener").isScript, true);
  assert.deepEqual(byId.get("canonical.undoable-delete-listener").shortcuts, []);
  assert.equal(byId.get("canonical.undo-delete").inMenu, true);
  assert.deepEqual(byId.get("canonical.undo-delete").shortcuts, ["ctrl+z"]);
  assert.equal(byId.get("canonical.undo-delete").isGlobalShortcut, false);
  assert.equal(byId.get("canonical.translate-en").inMenu, true);
  commands.forEach((entry) => assert.equal(entry.display, false, entry.internalId));
  assert.equal(commands.length, 15);
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
  const frequency = runtimeOnly(dispatch);
  assert.match(frequency, /frequent_usage_counts_v3/);
  assert.match(frequency, /CopyQCore\.recordFrequency/);
  assert.equal((frequency.match(/ignore\(\)/g) || []).length, 1);
  assert.match(frequency, /setData\(mimeOutputTab, 'Artifacts'\)/);
  assert.match(frequency, /setData\(mimeOutputTab, 'BIG'\)/);
  assert.match(frequency, /setData\(mimeOutputTab, 'Code'\)/);
  assert.match(frequency, /ItemSelection\('Frequent'\)/);
  assert.match(frequency, /setItemAtIndex/);
  assert.match(frequency, /\.move\(0\)/);
  assert.doesNotMatch(frequency, /remove\(/);
  assert.equal(frequency.indexOf("CopyQCore.recordFrequency") < frequency.indexOf("setData(mimeOutputTab, 'BIG')"), true);
  assert.equal(frequency.indexOf("CopyQCore.recordFrequency") < frequency.indexOf("setData(mimeOutputTab, 'Artifacts')"), true);
  assert.equal(frequency.indexOf("CopyQCore.recordFrequency") < frequency.indexOf("setData(mimeOutputTab, 'Code')"), true);
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

test("undo commands use the supported removal hook and private trash metadata without logging content", () => {
  const byId = new Map(buildCandidate().commands.map((entry) => [entry.internalId, entry]));
  const listener = runtimeOnly(byId.get("canonical.undoable-delete-listener").cmd);
  assert.match(listener, /const onItemsRemoved_|var onItemsRemoved_/);
  assert.match(listener, /global\.onItemsRemoved = function/);
  assert.match(listener, /ItemSelection\(\)\.current\(\)/);
  assert.match(listener, /ItemSelection\(\)\.selectRemovable\(\)/);
  assert.match(listener, /deselectSelection/);
  assert.doesNotMatch(listener, /current\(\)\.selectRemovable\(\)/);
  assert.match(listener, /application\/x-copyq-trash-source-tab/);
  assert.match(listener, /application\/x-copyq-trash-source-row/);
  assert.match(listener, /application\/x-copyq-trash-batch/);
  assert.match(listener, /application\/x-copyq-trash-deleted-at/);
  assert.match(listener, /application\/x-copyq-user-frequency-key/);
  assert.match(listener, /application\/x-copyq-user-frequency-count/);
  assert.match(listener, /CopyQCore\.dismissFrequency/);
  assert.match(listener, /CopyQCore\.isTrashExpired/);
  assert.match(listener, /onItemsRemoved_\(\)/);
  assert.match(listener, /copyq_undo_internal_remove/);
  assert.match(listener, /settings\(INTERNAL_REMOVE_KEY, ''\); cleanupTrash\(\)/);
  const handler = listener.slice(listener.indexOf("global.onItemsRemoved = function"));
  assert.equal(handler.indexOf("write(0, items)") < handler.lastIndexOf("onItemsRemoved_();"), true);
  assert.match(handler, /catch \(error\).*remove\.apply\(this, written\.rows\(\)\).*settings\(V3_KEY, oldStateValue/s);
  assert.doesNotMatch(listener, /serverLog|popup/);

  const undo = runtimeOnly(byId.get("canonical.undo-delete").cmd);
  assert.match(undo, /NOTHING_TO_UNDO/);
  assert.match(undo, /CopyQCore\.restoreFrequency/);
  assert.match(undo, /application\/x-copyq-trash-batch/);
  assert.match(undo, /application\/x-copyq-undo-restore-batch/);
  assert.match(undo, /copyq_undo_internal_remove/);
  assert.match(undo, /try \{/);
  assert.match(undo, /catch \(error\)/);
  assert.match(undo, /rollbackInserted = ItemSelection\(targetTab\)\.select/);
  assert.equal(undo.indexOf("inserted.setItemsFormat(RESTORE_BATCH_MIME, undefined)") < undo.indexOf("settings(INTERNAL_REMOVE_KEY, batch)"), true);
  assert.equal(undo.indexOf("remove.apply(this, trashRows)") < undo.indexOf("trashCommitted = true"), true);
  assert.equal(undo.indexOf("if (trashCommitted)") < undo.indexOf("rollbackInserted = inserted"), true);
  assert.match(undo, /&Clipboard/);
  assert.match(undo, /delete record\.item\[/);
  assert.doesNotMatch(undo, /serverLog/);
});
