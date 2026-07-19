"use strict";

const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const source = fs.readFileSync(path.join(__dirname, "shared-core.js"), "utf8");
module.exports = vm.runInNewContext(source + "\nCopyQCore;", {});
