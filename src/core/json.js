"use strict";


function validateJsonImport(text) { var parsed; var i; var key; var item; var value; try { parsed = JSON.parse(text); } catch (e) { return { ok: false, reason: 'JSON_PARSE_INVALID' }; } if (!parsed || Object.prototype.toString.call(parsed.copyq_items) !== '[object Array]') return { ok: false, reason: 'JSON_SHAPE_INVALID' }; for (i = 0; i < parsed.copyq_items.length; i += 1) { item = parsed.copyq_items[i]; if (!item || Object.prototype.toString.call(item) !== '[object Object]') return { ok: false, reason: 'JSON_SHAPE_INVALID' }; for (key in item) if (Object.prototype.hasOwnProperty.call(item, key)) { value = item[key]; if (typeof value !== 'string' && !(value && Object.prototype.toString.call(value) === '[object Object]' && typeof value.base64 === 'string')) return { ok: false, reason: 'JSON_SHAPE_INVALID' }; } } return { ok: true, value: parsed }; }

module.exports = { validateJsonImport: validateJsonImport };

