"use strict";

const assert = require("node:assert/strict");
const { spawnSync } = require("node:child_process");
const test = require("node:test");

const Core = require("../src/core-node");
const { buildCandidate } = require("../src/commands");

function command(identity) {
  return buildCandidate().commands.find((item) => item.internalId === identity);
}

function pythonLauncher() {
  for (const candidate of [
    { file: "py.exe", prefix: ["-3"] },
    { file: "python.exe", prefix: [] },
  ]) {
    const probe = spawnSync(candidate.file, candidate.prefix.concat(["--version"]), { encoding: "utf8" });
    if (probe.status === 0) return candidate;
  }
  throw new Error("Python 3 launcher is unavailable");
}

test("Markdown detection accepts strong structures and rejects ordinary text", () => {
  assert.equal(typeof Core.isMarkdown, "function");
  const positives = [
    "# Heading\n\nBody",
    "```js\nconst answer = 42;\n```",
    "Read [the guide](https://example.test/guide).",
    "> quoted text",
    "| Name | Value |\n| --- | ---: |\n| one | 1 |",
    "- first item\n- second item",
  ];
  const negatives = [
    "ordinary prose in one sentence",
    "https://example.test/path",
    "one-line - with a hyphen",
    "const answer = 42;\nconsole.log(answer);",
  ];
  for (const value of positives) assert.equal(Core.isMarkdown(value), true, value);
  for (const value of negatives) assert.equal(Core.isMarkdown(value), false, value);
});

test("Render Markdown is automatic but preserves plain text and only adds HTML", () => {
  const markdown = command("canonical.markdown-render");
  assert.equal(markdown.automatic, true);
  assert.equal(markdown.inMenu, true);
  assert.equal(markdown.input, "text/plain");
  assert.match(markdown.cmd, /CopyQCore\.isMarkdown/);
  assert.match(markdown.cmd, /setData\(mimeHtml/);
  assert.doesNotMatch(markdown.cmd, /setData\(mimeText/);
  assert.doesNotMatch(markdown.cmd, /copy\(/);
});

test("OCR reads the selected PNG directly and uses bilingual Tesseract without UI", () => {
  const ocr = command("canonical.ocr");
  assert.equal(ocr.input, "image/png");
  assert.match(ocr.cmd, /selectedItemsData\(\)/);
  assert.match(ocr.cmd, /item\['image\/png'\]/);
  assert.doesNotMatch(ocr.cmd, /screenshotSelect/);
  assert.doesNotMatch(ocr.cmd, /dialog\(/);
  assert.match(ocr.cmd, /'stdin', 'stdout', '-l', 'eng\+heb'/);
  assert.match(ocr.cmd, /env\('ProgramFiles'\)/);
  assert.match(ocr.cmd, /tesseract\.exe/);
  assert.match(ocr.cmd, /copy\(mimeText, text\)/);
  assert.match(ocr.cmd, /OCR_NO_PNG/);
  assert.match(ocr.cmd, /OCR_FAILED/);
  assert.match(ocr.cmd, /OCR_NO_TEXT/);
});

test("Highlight Code emits Qt-compatible continuous code markup", () => {
  const highlight = command("canonical.pygments-highlight");
  assert.match(highlight.cmd, /py\.exe/);
  assert.match(highlight.cmd, /python\.exe/);
  assert.match(highlight.cmd, /HtmlFormatter\(noclasses=True, nowrap=True, style="xcode"\)/);
  assert.match(highlight.cmd, /white-space: pre-wrap/);
  assert.match(highlight.cmd, /font-family: Consolas/);
  assert.match(highlight.cmd, /font-size: 14px/);
  assert.match(highlight.cmd, /cellpadding=/);
  assert.match(highlight.cmd, /bgcolor=/);
  assert.match(highlight.cmd, /<font color=/);
  assert.doesNotMatch(highlight.cmd, /Cascadia Code/);
  assert.doesNotMatch(highlight.cmd, /overflow-wrap|word-break|border-radius|line-height/);
  assert.match(highlight.cmd, /PYGMENTS_FAILED/);
});

test("the embedded Pygments renderer executes and wraps a long source line", () => {
  const highlight = command("canonical.pygments-highlight");
  const embedded = /var script = '([^']+)'/.exec(highlight.cmd);
  assert.ok(embedded, "embedded Python renderer is missing");
  const pythonScript = embedded[1].replace(/\\n/g, "\n");
  const source = `const value = "${"x".repeat(300)}";`;
  const launcher = pythonLauncher();
  const result = spawnSync(launcher.file, launcher.prefix.concat(["-c", pythonScript]), {
    input: source,
    encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /^<table width="100%" border="0" cellspacing="0" cellpadding="8" bgcolor="#ffffff">/);
  assert.match(result.stdout, /<td bgcolor="#ffffff"><pre style="[^"]*font-family: Consolas;[^"]*white-space: pre-wrap/);
  assert.match(result.stdout, /<font color="#[0-9A-Fa-f]{3,6}">/);
  assert.doesNotMatch(result.stdout, /<div|<span style=|line-height|background:/);
  assert.equal((result.stdout.match(/<pre\b/g) || []).length, 1);
  assert.equal((result.stdout.match(/<\/pre>/g) || []).length, 1);
});

test("Translate to English calls the private helper and copies only its result", () => {
  const translate = command("canonical.translate-en");
  assert.equal(translate.automatic, false);
  assert.match(translate.cmd, /selectedItemsData\(\)/);
  assert.match(translate.cmd, /pwsh\.exe/);
  assert.match(translate.cmd, /env\('ProgramFiles'\)/);
  assert.match(translate.cmd, /env\('LOCALAPPDATA'\)/);
  assert.match(translate.cmd, /CopyQCommandSuite/);
  assert.match(translate.cmd, /Invoke-CopyQAzureTranslation\.ps1/);
  assert.match(translate.cmd, /toBase64\(/);
  assert.match(translate.cmd, /fromBase64\(/);
  assert.doesNotMatch(translate.cmd, /null, text\)/);
  assert.match(translate.cmd, /'-NoLogo', '-NoProfile', '-NonInteractive', '-File'/);
  assert.match(translate.cmd, /copy\(mimeText, translated\)/);
  assert.match(translate.cmd, /TRANSLATE_NOT_CONFIGURED/);
  assert.match(translate.cmd, /TRANSLATE_AUTH_FAILED/);
  assert.match(translate.cmd, /TRANSLATE_REGION_FAILED/);
  assert.match(translate.cmd, /TRANSLATE_RATE_LIMITED/);
  assert.match(translate.cmd, /TRANSLATE_FAILED/);
  assert.match(translate.cmd, /TRANSLATE_EMPTY/);
  assert.doesNotMatch(translate.cmd, /translate\.google|open\(/i);
});

test("all canonical commands are free of machine-local and checkout paths", () => {
  const serialized = JSON.stringify(buildCandidate());
  assert.doesNotMatch(serialized, /[A-Z]:\\\\Users\\\\/i);
  assert.doesNotMatch(serialized, /Programming\\\\CopyQ/i);
  assert.match(command("canonical.markdown-render").cmd, /env\('APPDATA'\)/);
});
