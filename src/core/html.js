"use strict";

var common = require("./common");
var trim = common.trim;

function sanitizeHtml(value) { var html = String(value == null ? '' : value); html = html.replace(/\s(?:color|bgcolor)\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)/gi, ''); return html.replace(/\sstyle\s*=\s*("([^"]*)"|'([^']*)')/gi, function (match, quoted, doubleQuoted, singleQuoted) { var quote = quoted.charAt(0); var style = doubleQuoted !== undefined ? doubleQuoted : singleQuoted; var declarations = style.split(';').filter(function (declaration) { var name = trim(declaration.split(':')[0]).toLowerCase(); return name && name !== 'color' && name !== 'background' && name !== 'background-color'; }); return declarations.length ? ' style=' + quote + declarations.join(';') + quote : ''; }); }

module.exports = { sanitizeHtml: sanitizeHtml };

