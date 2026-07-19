"use strict";

function moonlanderCommand(internalId, name, transform, options, shortcut) {
  const body = [
    "copyq:",
    "var root = str(env('LOCALAPPDATA')).replace(/\\\\/g, '/') + '/MoonlanderTextTools';",
    "try { source(root + '/transformations.js'); source(root + '/transaction.js'); } catch (e) { notification('.id', 'moonlander-dependency', '.title', 'Moonlander Text Tools', '.message', 'MOONLANDER_DEPENDENCY_MISSING'); abort(); }",
    "MoonlanderTransaction.runTransaction(",
    `    MoonlanderTransforms.${transform},`,
    `    ${options},`,
    "    MoonlanderTransaction.createCopyQAdapter(root + '/Moonlander.Reselect.exe')",
    ");",
  ].join("\n");
  return {
    internalId,
    name,
    cmd: body,
    automatic: false,
    isScript: false,
    inMenu: true,
    input: "text/plain",
    display: false,
    isGlobalShortcut: true,
    globalShortcuts: [shortcut],
  };
}

function buildMoonlanderCommands() {
  return [
    moonlanderCommand("moonlander.smart-title", "Moonlander: Smart Title Case", "smartTitleCase", "{}", "F13"),
    moonlanderCommand("moonlander.cycle-case", "Moonlander: Cycle Case", "cycleCase", "{reselect: true}", "F19"),
    moonlanderCommand("moonlander.hebrew-layout", "Moonlander: Transplant Hebrew-English", "transplantHebrewEnglish", "{}", "F22"),
  ];
}

module.exports = { buildMoonlanderCommands };
