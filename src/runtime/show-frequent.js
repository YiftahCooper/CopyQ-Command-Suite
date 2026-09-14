"use strict";

const { copyq, script } = require("./command-source");

function frequentBody() { return copyq(["menu('Frequent');"], []); }

module.exports = frequentBody;

