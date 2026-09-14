"use strict";

const { buildCandidate, buildSecretProtection } = require("./commands");
const { buildMoonlanderCommands } = require("./moonlander-commands");

function buildPublicCommands() {
  const commands = buildCandidate().commands.concat(buildMoonlanderCommands());
  const identities = commands.map((entry) => entry.internalId);
  if (commands.length !== 18 || new Set(identities).size !== commands.length) {
    throw new Error("PUBLIC_COMMAND_INVENTORY_INVALID");
  }
  return { schema: 2, commands, alternatives: [buildSecretProtection()] };
}

module.exports = { buildPublicCommands };
