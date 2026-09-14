"use strict";


function validateRegex(text) { try { return { ok: true, value: new RegExp(text, 'i') }; } catch (e) { return { ok: false, reason: 'REGEX_INVALID' }; } }

module.exports = { validateRegex: validateRegex };

