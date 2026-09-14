"use strict";

var common = require("./common");
var trim = common.trim;

function credentialUrl(text) { return /^(?:https?|ftps?):\/\/[^/\s:@]+:[^/\s@]+@/i.test(text) || /[?&](?:access_token|api[_-]?key|password|secret|token)=[^&#\s]+/i.test(text) || /^https?:\/\/calendar\.google\.com\/calendar\/ical\/[^\s/]+\/private-[0-9a-f]{32}\/basic\.ics(?:[?#]|$)/i.test(text); }
// Only recognizable credentials are redacted inside documents. Do not apply
// the conservative standalone opaque-string heuristic to every prose word.
function isStandaloneUrl(value) {
  var text = trim(value);
  return /^(?:https?|ftps?):\/\/[^\s/?#]+[^\s]*$/i.test(text) || /^file:\/\/[^\r\n]+$/i.test(text);
}

module.exports = { credentialUrl: credentialUrl, isStandaloneUrl: isStandaloneUrl };

