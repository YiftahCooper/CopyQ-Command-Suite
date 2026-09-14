"use strict";

var common = require("./common");
var trim = common.trim;
var hasFormat = common.hasFormat;
var urls = require("./urls");
var credentialUrl = urls.credentialUrl;
var isStandaloneUrl = urls.isStandaloneUrl;

function decode(part) {
  var alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  var input = part.replace(/-/g, '+').replace(/_/g, '/'); var out = ''; var bits = 0; var bitCount = 0; var i; var n;
  while (input.length % 4) input += '=';
  for (i = 0; i < input.length; i += 1) { if (input.charAt(i) === '=') break; n = alphabet.indexOf(input.charAt(i)); if (n < 0) return null; bits = (bits << 6) | n; bitCount += 6; while (bitCount >= 8) { bitCount -= 8; out += String.fromCharCode((bits >> bitCount) & 255); } }
  return out;
}
function validJwt(text) { var parts = text.split('.'); var head; var body; try { head = parts.length === 3 ? JSON.parse(decode(parts[0])) : null; body = parts.length === 3 ? JSON.parse(decode(parts[1])) : null; } catch (e) { return false; } return !!(head && body && typeof head.alg === 'string' && /^[A-Za-z0-9_-]+$/.test(parts[2] || '')); }
function secretFormat(formats) { return hasFormat(formats, /(?:application\/x-copyq-secret|org\.nspasteboard\.concealedtype|clipboard viewer ignore|x-kde-passwordmanagerhint|nspasteboard concealed|mimesecret|com\.agilebits\.onepassword|1password|bitwarden|keepass|lastpass|password-manager)/i); }
function structuredNonSecret(text) {
  return isStandaloneUrl(text)
    || /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(text)
    || /^(?:[A-Za-z]:[\\/]|\\\\|\/)[^\r\n]+$/.test(text)
    || /^v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(text)
    || /^[A-Z][A-Z0-9]{1,9}-\d{1,10}$/.test(text);
}
function historicalOpaqueSecret(text) {
  var classes = 0;
  if (text.length < 10 || text.length > 3000 || /\s/.test(text)) return false;
  if (/[a-z]/.test(text)) classes += 1;
  if (/[A-Z]/.test(text)) classes += 1;
  if (/\d/.test(text)) classes += 1;
  return classes >= 2;
}
function isHighConfidenceSecret(value, formats) {
  var text = trim(value);
  if (secretFormat(formats)) return true;
  if (/^-----BEGIN (?:[A-Z0-9 ]+ )?(?:PRIVATE KEY|OPENSSH PRIVATE KEY)-----/m.test(text) || validJwt(text)) return true;
  if (/^(?:sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{12,}|AIza[0-9A-Za-z_-]{30,}|AKIA[0-9A-Z]{16}|npm_[A-Za-z0-9_-]{20,}|pypi-[A-Za-z0-9_-]{20,})$/.test(text)) return true;
  if (/^authorization:\s*(?:bearer|basic|token)\s+\S{12,}$/i.test(text)) return true;
  if(/^\s*(?:export\s+)?(?:[A-Za-z_][A-Za-z0-9_]*(?:PASSWORD|TOKEN|SECRET|API_KEY)[A-Za-z0-9_]*|PASSWORD|TOKEN|SECRET|API_KEY)\s*=\s*\S{12,}\s*$/i.test(text)) return true;
  if (credentialUrl(text)) return true;
  if (/^[0-9a-f]{32,128}$/i.test(text)) return true;
  if (structuredNonSecret(text)) return false;
  return historicalOpaqueSecret(text);
}
function redactSecrets(value) {
  var original = String(value == null ? '' : value); var marker = '[REDACTED]';
  function replacement(value) { return !value || /^(?:\[REDACTED\]|\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$env:[A-Za-z_][A-Za-z0-9_]*|process\.env\.[A-Za-z_][A-Za-z0-9_]*)$/.test(value) ? value : marker; }
  function urlPart(url) {
    url = url.replace(/^((?:https?|ftps?):\/\/[^/\s:@]+:)([^/\s@]+)(@)/i, function (_, before, password, after) { return before + replacement(password) + after; });
    url = url.replace(/([?&#](?:access_token|api[_-]?key|password|secret|token)=)([^&#\s]+)/gi, function (_, before, secret) { return before + replacement(secret); });
    return url.replace(/^(https?:\/\/calendar\.google\.com\/calendar\/ical\/[^\s/]+\/private-)[0-9a-f]{32}(\/basic\.ics(?:[?#]|$))/i, '$1' + marker + '$2');
  }
  function textPart(text) {
    text = text.replace(/-----BEGIN ((?:[A-Z0-9]+ )*PRIVATE KEY)-----[\s\S]*?(?:-----END \1-----|$)/g, marker);
    text = text.replace(/(\bauthorization\s*:\s*(?:bearer|basic|token)\s+)([^\s"',;]+)/gi, function (_, before, secret) { return before + replacement(secret); });
    text = text.replace(/(\b(?:[A-Za-z_][A-Za-z0-9_]*[_-])?(?:password|passwd|token|secret|api[_-]?key|client[_-]?secret|access[_-]?token)(?:[_-][A-Za-z0-9_]+)?["']?\s*[:=]\s*)(?:"((?:\\.|[^"\\])*)"|'((?:\\.|[^'\\])*)'|(\[REDACTED\]|\$\{[A-Za-z_][A-Za-z0-9_]*\}|[^\s,;}\]]+))/gi, function (_, before, doubleQuoted, singleQuoted, bare) {
      if (doubleQuoted !== undefined) return before + '"' + replacement(doubleQuoted) + '"';
      if (singleQuoted !== undefined) return before + "'" + replacement(singleQuoted) + "'";
      return before + replacement(bare);
    });
    text = text.replace(/\b(?:sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{12,}|AIza[0-9A-Za-z_-]{30,}|AKIA[0-9A-Z]{16}|npm_[A-Za-z0-9_-]{20,}|pypi-[A-Za-z0-9_-]{20,})\b/g, marker);
    return text.replace(/\b[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, function (candidate) { return validJwt(candidate) ? marker : candidate; });
  }
  // Separate URL spans so token-like path components are never guessed at.
  var result = ''; var position = 0; var urls = /(?:https?|ftps?|file):\/\/[^\s<>"']+/gi; var match;
  while ((match = urls.exec(original))) { result += textPart(original.slice(position, match.index)) + urlPart(match[0]); position = urls.lastIndex; }
  result += textPart(original.slice(position));
  return { text: result, redacted: result !== original };
}

// Shared safety decision for integrated routing and protection-only installs.
// Destination classification and frequency state intentionally live elsewhere.
function inspectClipboard(input) {
  var text = String(input && input.text != null ? input.text : '');
  var formats = input && input.formats || [];
  if (secretFormat(formats)) return { action: 'ignored', frequencyEligible: false };
  var redaction = redactSecrets(text);
  var standalone = trim(redaction.text).replace(/[\u200b\u200e\u200f\u2066-\u2069]/g, '') === '[REDACTED]' || (!/[\r\n]/.test(trim(text)) && /^(?:authorization\s*:|(?:export\s+)?[A-Za-z_][A-Za-z0-9_]*\s*=)/i.test(trim(text)) && isHighConfidenceSecret(text));
  if (standalone || (!redaction.redacted && isHighConfidenceSecret(text))) return { action: 'ignored', frequencyEligible: false };
  if (redaction.redacted) return { action: 'redacted', frequencyEligible: false, redactedText: redaction.text };
  if (hasFormat(formats, /^image\//i) || (input && input.mimeOwner && formats.indexOf(input.mimeOwner) >= 0) || (input && input.mimeHidden && formats.indexOf(input.mimeHidden) >= 0)) return { action: 'passthrough', frequencyEligible: false };
  return { action: 'allowed', frequencyEligible: trim(text) !== '' };
}

module.exports = { validJwt: validJwt, secretFormat: secretFormat, isHighConfidenceSecret: isHighConfidenceSecret, redactSecrets: redactSecrets, inspectClipboard: inspectClipboard };
