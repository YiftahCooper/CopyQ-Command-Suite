"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");

const root = path.resolve(__dirname, "..");
const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest", "public-commands.json"), "utf8"));
const absolute = (relative) => path.join(root, ...relative.split("/"));

function internalIds(ini) {
  return [...ini.matchAll(/^(?:\d+\\)?InternalId=(.+)\r?$/gm)].map((match) => match[1]);
}

test("public manifest closes the complete 36-command inventory", () => {
  assert.equal(manifest.schema, 1);
  assert.equal(manifest.license, "GPL-3.0-only");
  assert.equal(manifest.commands.length, 16);
  assert.equal(manifest.referenceOnly.length, 11);
  assert.equal(manifest.copyqDefaults.length, 9);
  assert.equal(manifest.commands.length + manifest.referenceOnly.length + manifest.copyqDefaults.length, 36);
  assert.equal(manifest.commands.filter((entry) => entry.group === "canonical").length, 13);
  assert.equal(manifest.commands.filter((entry) => entry.group === "moonlander").length, 3);
});

test("public identities, names, outputs, and shortcuts are unique", () => {
  for (const field of ["identity", "name", "output"]) {
    const values = manifest.commands.map((entry) => entry[field]);
    assert.equal(new Set(values.map((value) => value.toLowerCase())).size, values.length, `${field} must be unique`);
  }
  const shortcuts = manifest.commands.filter((entry) => entry.shortcut);
  assert.equal(new Set(shortcuts.map((entry) => entry.shortcut.toLowerCase())).size, shortcuts.length);
  const owners = Object.fromEntries(shortcuts.filter((entry) => /^f(?:13|19|22)$/i.test(entry.shortcut)).map((entry) => [entry.shortcut.toLowerCase(), entry.identity]));
  assert.deepEqual(owners, {
    f13: "moonlander.smart-title",
    f19: "moonlander.cycle-case",
    f22: "moonlander.hebrew-layout",
  });
});

test("Moonlander commands declare the public companion repository", () => {
  const url = "https://github.com/YiftahCooper/Moonlander-Custom-Config";
  assert.equal(manifest.companionRepositories.moonlander, url);
  for (const command of manifest.commands.filter((entry) => entry.group === "moonlander")) {
    assert.equal(command.companion, "moonlander");
    assert.equal(command.provenance, "original");
  }
});

test("reference-only commands have upstream links and are absent from public outputs", () => {
  const publicNames = new Set(manifest.commands.map((entry) => entry.name.toLowerCase()));
  for (const reference of manifest.referenceOnly) {
    assert.match(reference.url, /^https:\/\/github\.com\/hluk\/copyq-commands\/blob\/master\/commands\//);
    assert.ok(reference.contributors.length > 0, reference.name);
    assert.equal(publicNames.has(reference.name.toLowerCase()), false, reference.name);
  }
});

test("every public command source and individual output exists", () => {
  for (const command of manifest.commands) {
    assert.equal(fs.existsSync(absolute(command.source)), true, `missing source: ${command.source}`);
    assert.equal(fs.existsSync(absolute(command.output)), true, `missing output: ${command.output}`);
  }
});

test("public files contain no machine-local path or private artifact marker", () => {
  const unique = new Set(manifest.publicFiles);
  assert.equal(unique.size, manifest.publicFiles.length, "publicFiles must be unique");
  const forbiddenPath = /[A-Z]:\\Users\\|copyq_commands_backup|Found Online|Who you are|private-settings|private-items|receipts\//i;
  for (const relative of manifest.publicFiles) {
    assert.equal(path.isAbsolute(relative), false, relative);
    if (!fs.existsSync(absolute(relative)) || fs.statSync(absolute(relative)).isDirectory()) continue;
    if (relative === ".gitignore" || relative === "tests/public-package.test.js") continue;
    const content = fs.readFileSync(absolute(relative), "utf8");
    assert.doesNotMatch(content, forbiddenPath, relative);
  }
});

test("all declared public files and bundles exist", () => {
  for (const relative of manifest.publicFiles) {
    assert.equal(fs.existsSync(absolute(relative)), true, `missing public file: ${relative}`);
  }
  assert.deepEqual(manifest.bundles.map((entry) => entry.count), [13, 3, 16]);
});

test("individual exports and bundles contain the exact manifest identities", () => {
  for (const command of manifest.commands) {
    assert.equal(fs.existsSync(absolute(command.output)), true, command.output);
    assert.deepEqual(internalIds(fs.readFileSync(absolute(command.output), "utf8")), [command.identity]);
  }
  for (const bundle of manifest.bundles) {
    assert.equal(fs.existsSync(absolute(bundle.output)), true, bundle.output);
    const expected = manifest.commands
      .filter((entry) => bundle.group === "all" || entry.group === bundle.group)
      .map((entry) => entry.identity);
    assert.deepEqual(internalIds(fs.readFileSync(absolute(bundle.output), "utf8")), expected);
    assert.equal(expected.length, bundle.count);
  }
});

test("public documentation covers every command, dependency, output, and provenance link", () => {
  const documentationPaths = ["README.md", "docs/commands/COMMANDS.md", "docs/CREDITS.md"];
  for (const relative of documentationPaths) assert.equal(fs.existsSync(absolute(relative)), true, relative);
  const documentation = documentationPaths.map((relative) => fs.readFileSync(absolute(relative), "utf8")).join("\n");
  for (const command of manifest.commands) {
    assert.match(documentation, new RegExp(command.name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")), command.name);
    assert.equal(documentation.includes(command.output), true, command.output);
    for (const dependency of command.dependencies) assert.equal(documentation.includes(dependency), true, dependency);
  }
  for (const reference of manifest.referenceOnly) assert.equal(documentation.includes(reference.url), true, reference.name);
  assert.equal(documentation.includes(manifest.companionRepositories.moonlander), true);
  for (const code of ["SECRET_IGNORED", "MARKDOWN_FAILED", "PYGMENTS_FAILED", "OCR_FAILED", "TRANSLATE_NOT_CONFIGURED"]) {
    assert.equal(documentation.includes(code), true, code);
  }
});

test("public license and release metadata declare GPL-3.0-only", () => {
  const readme = fs.readFileSync(absolute("README.md"), "utf8");
  const license = fs.readFileSync(absolute("LICENSE"), "utf8");
  const changelog = fs.readFileSync(absolute("CHANGELOG.md"), "utf8");
  assert.match(readme, /GPL-3\.0-only/);
  assert.match(license, /GNU GENERAL PUBLIC LICENSE/);
  assert.match(license, /Version 3, 29 June 2007/);
  assert.match(license, /END OF TERMS AND CONDITIONS/);
  assert.match(changelog, /Initial public release/);
});

test("PUBLIC-FILES and the non-ignored workspace close to the same exact set", () => {
  const pathspecText = fs.readFileSync(absolute("PUBLIC-FILES.txt"), "utf8");
  const pathspecLines = pathspecText.split(/\r?\n/);
  if (pathspecLines.at(-1) === "") pathspecLines.pop();
  assert.equal(pathspecLines.includes(""), false, "PUBLIC-FILES.txt contains an empty Git pathspec");
  const allowlist = pathspecLines;
  assert.deepEqual(allowlist, manifest.publicFiles);
  const git = spawnSync("C:\\Program Files\\Git\\cmd\\git.exe", ["ls-files", "--others", "--exclude-standard"], {
    cwd: root,
    encoding: "utf8",
  });
  assert.equal(git.status, 0, git.stderr);
  const visible = git.stdout.split(/\r?\n/).filter(Boolean).map((entry) => entry.replace(/\\/g, "/")).sort();
  assert.deepEqual(visible, manifest.publicFiles.slice().sort());
});
