"use strict";


function trim(value) { return String(value == null ? '' : value).replace(/^\s+|\s+$/g, ''); }
function hasFormat(formats, expression) { var i; for (i = 0; i < (formats || []).length; i += 1) if (expression.test(String(formats[i]))) return true; return false; }

module.exports = { trim: trim, hasFormat: hasFormat };

