"use strict";

const { copyq, script } = require("./command-source");

function htmlSanitizerBody() { return copyq(["var html = str(data(mimeHtml)); if (!html) abort();", "var sanitized = CopyQCore.sanitizeHtml(html); if (sanitized === html) abort(); setData(mimeHtml, sanitized);"], ["html"]); }

module.exports = htmlSanitizerBody;

