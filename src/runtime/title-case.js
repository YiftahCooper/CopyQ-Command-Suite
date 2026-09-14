"use strict";

const { copyq, script } = require("./command-source");

function titleBody() { return copyq(["if (!copy()) abort(); var text = str(clipboard()); var result = CopyQCore.titleCase(text); if (result === text) abort(); copy(result); paste();"], ["casing"]); }

module.exports = titleBody;

