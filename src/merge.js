"use strict";

function commandIdentity(command) { return command && typeof command === "object" ? (command.internalId || (command.meta && command.meta.canonicalId)) : undefined; }

function managedEntry(manifest, identity) { return (manifest.managed || []).find((entry) => entry.identity === identity); }

function matchManaged(command, manifest) {
  const internalId = commandIdentity(command);
  const name = command && command.name;
  for (const entry of manifest.managed || []) {
    const aliases = entry.aliases || {};
    if (internalId === entry.identity || (aliases.internalIds || []).includes(internalId) || (aliases.names || []).includes(name)) return entry.identity;
  }
  return undefined;
}

function isProtected(command, manifest) {
  const identity = commandIdentity(command);
  return (manifest.protectedIdentities || []).includes(identity) || (manifest.protectedNames || []).includes(command && command.name);
}

function mergeCommands(existing, candidate, manifest) {
  const byIdentity = new Map();
  for (const command of candidate || []) {
    const identity = commandIdentity(command);
    if (byIdentity.has(identity)) throw new Error("duplicate candidate identity: " + identity);
    if ((manifest.protectedIdentities || []).includes(identity)) throw new Error("protected command cannot be replaced: " + identity);
    if (!managedEntry(manifest, identity)) throw new Error("candidate command is not managed: " + identity);
    byIdentity.set(identity, command);
  }
  const inserted = new Set();
  const result = [];
  for (const command of existing || []) {
    if (isProtected(command, manifest)) { result.push(command); continue; }
    const identity = matchManaged(command, manifest);
    if (identity && byIdentity.has(identity)) {
      if (!inserted.has(identity)) { result.push(byIdentity.get(identity)); inserted.add(identity); }
      continue;
    }
    result.push(command);
  }
  for (const command of candidate || []) if (!inserted.has(commandIdentity(command))) result.push(command);
  return result;
}

function expectedMergedCount(existing, candidate, manifest) { return mergeCommands(existing, candidate, manifest).length; }

module.exports = { commandIdentity, expectedMergedCount, matchManaged, mergeCommands };
