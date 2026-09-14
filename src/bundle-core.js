"use strict";

const fs = require("node:fs");
const path = require("node:path");

// Build-time dependency graph. CopyQ receives self-contained code, never file
// paths, Node APIs, or a separately installed module loader.
const dependencies = {
  common: [], urls: ["common"], secrets: ["common", "urls"],
  artifacts: ["common"], code: [], markdown: [], frequency: ["common"],
  trash: [], routing: ["common", "secrets", "urls", "artifacts", "code"],
  casing: [], html: ["common"], json: [], regex: [], dependencies: [],
};

function dependencyOrder(requested) {
  const ordered = [];
  const visited = new Set();
  function visit(name) {
    if (!Object.hasOwn(dependencies, name)) throw new Error("UNKNOWN_CORE_MODULE: " + name);
    if (visited.has(name)) return;
    visited.add(name);
    dependencies[name].forEach(visit);
    ordered.push(name);
  }
  requested.forEach(visit);
  return ordered;
}

function bundleCore(requested) {
  if (!requested.length) return "";
  const order = dependencyOrder(requested);
  const lines = ["var CopyQCore = (function () {", "  var modules = {};", "  var api = {};"];
  for (const name of order) {
    const source = fs.readFileSync(path.join(__dirname, "core", name + ".js"), "utf8").replace(/\r\n/g, "\n");
    const imports = dependencies[name].map((dependency) => `case './${dependency}': return modules.${dependency};`).join(" ");
    lines.push(`  modules.${name} = (function () {`, "    var module = { exports: {} };",
      `    function require(id) { switch (id) { ${imports} default: throw new Error('UNDECLARED_CORE_IMPORT'); } }`,
      source, "    return module.exports;", "  }());");
    lines.push(`  for (var key in modules.${name}) if (Object.prototype.hasOwnProperty.call(modules.${name}, key)) api[key] = modules.${name}[key];`);
  }
  lines.push("  return api;", "}());");
  return lines.join("\n");
}

module.exports = { bundleCore, dependencyOrder, moduleNames: Object.keys(dependencies) };
