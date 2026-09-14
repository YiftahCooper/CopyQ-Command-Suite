"use strict";

const { copyq, script } = require("./command-source");

function copyJsonBody() { return copyq(["function out(d) { var s = str(d); return d.equals(new ByteArray(s)) ? s : { base64: toBase64(d) }; }", "var items = selectedItemsData(); for (var i in items) for (var f in items[i]) items[i][f] = out(items[i][f]); copy(JSON.stringify({ copyq_items: items }, null, 2));"], []); }

module.exports = copyJsonBody;

