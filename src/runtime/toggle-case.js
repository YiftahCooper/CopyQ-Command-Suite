"use strict";

const { copyq, script } = require("./command-source");

function toggleBody() { return copyq(["if (!copy()) abort(); var text = str(clipboard()); var result = CopyQCore.toggleCase(text); if (result === text) abort(); copy(result); paste();"], ["casing"]); }

module.exports = toggleBody;

