"use strict";

const { copyq, script } = require("./command-source");

function pasteJsonBody() { return copyq(["var checked = CopyQCore.validateJsonImport(str(clipboard())); if (!checked.ok) { notification('.id', 'json', '.message', checked.reason); abort(); }", "function incoming(d) { return typeof d === 'string' ? new ByteArray(d) : fromBase64(d.base64); } for (var i in checked.value.copyq_items) { var item = checked.value.copyq_items[i]; for (var f in item) item[f] = incoming(item[f]); setItem(i, item); }"], ["json"]); }

module.exports = pasteJsonBody;

