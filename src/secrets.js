"use strict";
const core = require("./core/secrets");
module.exports = { hasPasswordManagerFormat: function (formats) { return core.isHighConfidenceSecret("", formats); }, isCredentialUrl: function (text) { return core.isHighConfidenceSecret(text, []) && /^https?:\/\//i.test(String(text)); }, isHighConfidenceSecret: core.isHighConfidenceSecret, isStructurallyValidJwt: function (text) { return core.isHighConfidenceSecret(text, []) && String(text).indexOf(".") >= 0; } };
