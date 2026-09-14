"use strict";

const assert = require("node:assert/strict");
const vm = require("node:vm");
const test = require("node:test");
const { buildCandidate } = require("../src/commands");

test("bundled feature modules execute the same public operations as direct Node imports", () => {
  const { bundleCore } = require("../src/bundle-core");
  const cases = [
    ["secrets", "redactSecrets", ["Use ghp_" + "a".repeat(36)], { text: "Use [REDACTED]", redacted: true }],
    ["routing", "route", [{ text: "https://example.test/path" }], { action: "url", frequencyEligible: true }],
    ["artifacts", "isArtifact", ['{"ok":true,"status":"done"}'], true],
    ["code", "isCode", ["const value = 1;"], true],
    ["html", "sanitizeHtml", ['<font color="red">Hello</font>'], "<font>Hello</font>"],
    ["regex", "validateRegex", ["["], { ok: false, reason: "REGEX_INVALID" }],
    ["json", "validateJsonImport", ["{"], { ok: false, reason: "JSON_PARSE_INVALID" }],
    ["trash", "isTrashExpired", ["2026-01-01T00:00:00Z", Date.parse("2026-01-31T00:00:00Z"), 30 * 86400000], true],
  ];
  for (const [name, method, args, expected] of cases) {
    const embedded = vm.runInNewContext(bundleCore([name]) + "\nCopyQCore;", {});
    const direct = require("../src/core/" + name);
    for (const core of [embedded, direct]) assert.equal(JSON.stringify(core[method](...args)), JSON.stringify(expected));
  }
  assert.throws(() => bundleCore(["does-not-exist"]), /UNKNOWN_CORE_MODULE/);
});

// Export closure is a user-facing distribution boundary: unrelated features
// must not be present when somebody imports only this utility.
test("title-case import contains usable casing helpers but no secret or routing implementation", () => {
  const source = buildCandidate().commands.find((item) => item.internalId === "canonical.smart-title").cmd.replace(/^copyq:\s*/, "");
  const core = vm.runInNewContext(source.slice(0, source.lastIndexOf("}());") + 5) + "\nCopyQCore;", {});
  assert.equal(core.titleCase("a tale of two cities"), "A Tale of Two Cities");
  assert.equal(core.isHighConfidenceSecret, undefined);
  assert.equal(core.route, undefined);
  assert.equal(core.recordFrequency, undefined);
});

test("Markdown import can classify Markdown without including frequency or secrets", () => {
  const source = buildCandidate().commands.find((item) => item.internalId === "canonical.markdown-render").cmd.replace(/^copyq:\s*/, "");
  const core = vm.runInNewContext(source.slice(0, source.lastIndexOf("}());") + 5) + "\nCopyQCore;", {});
  assert.equal(core.isMarkdown("# Title\n\nA paragraph"), true);
  assert.equal(core.isMarkdown("An ordinary sentence"), false);
  assert.equal(core.recordFrequency, undefined);
  assert.equal(core.redactSecrets, undefined);
});

test("standalone protection redacts without changing destinations or touching frequency state", () => {
  const { buildSecretProtection } = require("../src/commands");
  assert.equal(typeof buildSecretProtection, "function");
  const command = buildSecretProtection();
  const event = { "text/plain": "Use ghp_" + "a".repeat(36), "text/html": "alternate secret", output: "Existing Tab" };
  const stop = new Error("abort");
  const context = {
    commands: () => [command], dataFormats: () => Object.keys(event), data: (key) => event[key] || "", str: String,
    mimeText: "text/plain", mimeOwner: "owner", mimeHidden: "hidden", mimeOutputTab: "output",
    setData: (key, value) => { event[key] = value; return true; }, removeData: (key) => { delete event[key]; },
    notification: () => {}, abort: () => { throw stop; },
    settings: () => assert.fail("standalone protection must not access frequency state"),
    tab: () => assert.fail("standalone protection must not select or create tabs"),
    ignore: () => assert.fail("redacted content must remain eligible for history"),
  };
  try { vm.runInNewContext(command.cmd.replace(/^copyq:\s*/, ""), context); } catch (error) { if (error !== stop) throw error; }
  assert.deepEqual(event, { "text/plain": "Use [REDACTED]", output: "Existing Tab" });
});

test("installing both automatic handlers fails closed before routing or frequency writes", () => {
  const { buildSecretProtection } = require("../src/commands");
  assert.equal(typeof buildSecretProtection, "function");
  const router = buildCandidate().commands[0];
  const standalone = buildSecretProtection();
  for (const command of [router, standalone]) {
    let ignored = false;
    const notices = [];
    const stop = new Error("abort");
    const context = {
      commands: () => [router, standalone], notification: (...args) => notices.push(args),
      ignore: () => { ignored = true; }, abort: () => { throw stop; },
      settings: () => assert.fail("conflict must stop before counting"),
      dataFormats: () => assert.fail("conflict must stop before inspecting data"),
    };
    try { vm.runInNewContext(command.cmd.replace(/^copyq:\s*/, ""), context); } catch (error) { if (error !== stop) throw error; }
    assert.equal(ignored, true);
    assert.match(JSON.stringify(notices), /SECRET_HANDLER_CONFLICT/);
  }
});
