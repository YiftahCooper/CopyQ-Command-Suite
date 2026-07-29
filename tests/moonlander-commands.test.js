"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const { buildMoonlanderCommands } = require("../src/moonlander-commands");
const { buildPublicCommands } = require("../src/public-commands");

test("Moonlander exports exact identities, names, and shortcut ownership", () => {
  const commands = buildMoonlanderCommands();
  assert.deepEqual(commands.map((entry) => [entry.internalId, entry.name, entry.globalShortcuts[0]]), [
    ["moonlander.smart-title", "Moonlander: Smart Title Case", "F13"],
    ["moonlander.cycle-case", "Moonlander: Cycle Case", "F19"],
    ["moonlander.hebrew-layout", "Moonlander: Transplant Hebrew-English", "F22"],
  ]);
});

test("Moonlander commands resolve their companion runtime from LOCALAPPDATA", () => {
  for (const command of buildMoonlanderCommands()) {
    assert.match(command.cmd, /env\('LOCALAPPDATA'\)/);
    assert.match(command.cmd, /MoonlanderTextTools/);
    assert.match(command.cmd, /transformations\.js/);
    assert.match(command.cmd, /transaction\.js/);
    assert.match(command.cmd, /Moonlander\.Reselect\.exe/);
    assert.doesNotMatch(command.cmd, /[A-Z]:\\\\Users\\\\/i);
  }
});

test("public command model contains fifteen canonical and three Moonlander commands", () => {
  const first = buildPublicCommands();
  const second = buildPublicCommands();
  assert.equal(first.schema, 2);
  assert.equal(first.commands.length, 18);
  assert.deepEqual(first, second);
  assert.equal(new Set(first.commands.map((entry) => entry.internalId)).size, 18);
  assert.equal(first.commands.filter((entry) => /^canonical\./.test(entry.internalId)).length, 15);
  assert.equal(first.commands.filter((entry) => /^moonlander\./.test(entry.internalId)).length, 3);
});
