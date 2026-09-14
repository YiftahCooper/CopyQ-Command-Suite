"use strict";

const { copyq } = require("./command-source");
const protectionLines = require("./secret-protection-fragment");

// Alternative to Clipboard Router for users who only want secret protection.
module.exports = function secretProtectionBody() {
  return copyq(protectionLines("inspectClipboard"), ["secrets"]);
};
