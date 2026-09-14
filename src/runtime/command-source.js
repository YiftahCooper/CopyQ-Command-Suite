"use strict";

const { bundleCore } = require("../bundle-core");

function script(lines, modules = []) {
  const helpers = bundleCore(modules);
  return (helpers ? helpers + "\n" : "") + lines.join("\n");
}
function copyq(lines, modules = []) { return "copyq:\n" + script(lines, modules); }

module.exports = { copyq, script };
