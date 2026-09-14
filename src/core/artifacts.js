"use strict";

var common = require("./common");
var trim = common.trim;

function isArtifact(value) {
  var text = trim(value); var parsed; var lines; var matches;
  if (!text) return false;
  if (/^[\[{]/.test(text)) {
    try {
      parsed = JSON.parse(text);
      if (Object.prototype.toString.call(parsed) === '[object Array]') return parsed.length >= 2;
      if (parsed && Object.prototype.toString.call(parsed) === '[object Object]') return Object.keys(parsed).length >= 2;
    } catch (e) {}
  }
  if (!/[\r\n]/.test(text)) return false;
  lines = text.split(/\r?\n/).filter(function (line) { return trim(line) !== ''; });
  if (lines.length < 2) return false;
  if (/^diff --git\s/m.test(text) || /^@@\s+-\d+(?:,\d+)?\s+\+\d+(?:,\d+)?\s+@@/m.test(text)) return true;
  if (/---\s+backtrace\s+---/i.test(text) || /^Traceback \(most recent call last\):/m.test(text)) return true;
  matches = text.match(/^\s*at\s+\S.+$/gm); if (matches && matches.length >= 2) return true;
  if (/^(?:PS\s+[A-Za-z]:\\[^>\r\n]*>|[$#>])\s*\S/m.test(text)) return true;
  if (/`\s*$/m.test(text) && /^\s{2,}-(?:\w|-)\S*/m.test(text)) return true;
  matches = text.match(/^(?:\[[0-2]?\d:[0-5]\d:[0-5]\d\]|\d{4}-\d{2}-\d{2}[T ][^\s]+|\s*(?:TRACE|DEBUG|INFO|WARN|ERROR|FATAL)\b).+$/gim);
  if (matches && matches.length >= 2) return true;
  if (/^RELEASE_STAGE_FAILED:/m.test(text) && /(?:reason=|backtrace)/i.test(text)) return true;
  matches = text.match(/^\s*(?:\[[^\]\r\n]+\]|[A-Za-z_][A-Za-z0-9_.-]*\s*(?:=|:)\s*\S.*)$/gm);
  return !!(matches && matches.length >= 3);
}

module.exports = { isArtifact: isArtifact };

