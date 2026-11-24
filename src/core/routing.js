"use strict";

var common = require("./common");
var trim = common.trim;
var hasFormat = common.hasFormat;
var secrets = require("./secrets");
var inspectClipboard = secrets.inspectClipboard;
var urls = require("./urls");
var isStandaloneUrl = urls.isStandaloneUrl;
var artifacts = require("./artifacts");
var isArtifact = artifacts.isArtifact;
var code = require("./code");
var isCode = code.isCode;

function isBareHostnameList(text) {
  // Limit the guess to common endings to avoid routing ordinary filenames
  // and dotted identifiers into URLs. No DNS lookup is needed.
  var hostname = /^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+(?:com|org|net|edu|gov|mil|arpa|info|biz|io|ai|app|dev|cloud|co|uk|il|de|eu)$/i;
  return trim(text).split(/\r\n?|\n/).every(function (line) {
    var name = trim(line).replace(/\.$/, '');
    return name.length <= 253 && hostname.test(name);
  });
}

function route(input) {
  var text = String(input && input.text != null ? input.text : '');
  var policy = inspectClipboard(input); var eligible = policy.frequencyEligible;
  if (policy.action === 'ignored' || policy.action === 'passthrough') return policy;
  if (policy.action === 'redacted') {
    var action = text.length >= 5000 ? 'big' : isStandaloneUrl(text) ? 'url' : isArtifact(policy.redactedText) ? 'artifacts' : isCode(policy.redactedText) ? 'code' : 'default';
    return { action: action, frequencyEligible: false, redactedText: policy.redactedText };
  }
  if (text.length >= 5000) return { action: 'big', frequencyEligible: eligible };
  if (isStandaloneUrl(text) || isBareHostnameList(text)) return { action: 'url', frequencyEligible: eligible };
  if (isArtifact(text)) return { action: 'artifacts', frequencyEligible: eligible };
  if (isCode(text)) return { action: 'code', frequencyEligible: eligible };
  return { action: 'default', frequencyEligible: eligible };
}

module.exports = { route: route };
