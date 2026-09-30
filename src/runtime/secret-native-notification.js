"use strict";

const { copyq } = require("./command-source");
const saveOnce = require("./secret-save-once");

// Runs as a separate CopyQ action. Its code contains only a fingerprint and
// random notification IDs, never the original clipboard data or its MIME map.
function nativeSecretNotice(request) {
  var key = 'secret_notification_current';
  function current() { return str(settings(key)) === request.id; }
  function unavailable() {
    if (current()) try {
      notification('.id', 'secret-save-unavailable', '.title', 'Clipboard protection',
        '.message', request.reason + '\nSAVE_UNAVAILABLE', '.time', 7000);
    } catch (e) {}
  }
  function close(id) {
    if (/^copyq-secret-[0-9a-z-]+$/.test(id || '')) {
      try { execute(helper, '-appID', 'copyq', '-close', id); } catch (e) {}
    }
  }
  var helper;
  try {
    if (!current()) return;
    if (!/^[0-9a-f]{64}$/.test(request.expected)
        || !/^SECRET_(?:IGNORED|REDACTED)$/.test(request.reason)) return;
    var executable = str(info('exe')).replace(/\\/g, '/');
    if (!/\/copyq\.exe$/i.test(executable)) { unavailable(); return; }
    helper = executable.replace(/\/copyq\.exe$/i, '/snoretoast.exe');
    if (!(new File(helper)).exists()) { unavailable(); return; }
    // Unique IDs prevent an old worker's cleanup from closing a newer toast.
    close(request.previous);
    if (!current()) return;
    var result;
    try {
      result = execute(helper, '-appID', 'copyq', '-id', request.id,
        '-t', request.reason === 'SECRET_IGNORED' ? 'Secret excluded from history' : 'Secrets removed from history',
        '-m', request.reason + '\nClick to save the current original once...', '-d', 'short', '-silent');
    } finally {
      close(request.id);
    }
    if (!current()) return;
    if (result && result.exit_code === 0) saveProtectedClipboardOnce(request.expected, current, request.destination);
    else if (!result || [1, 2, 3].indexOf(result.exit_code) < 0) unavailable();
  } catch (e) {
    unavailable();
  }
  // Keep one nonsensitive ID until the next dispatch overwrites it. A separate
  // current()/clear pair can erase a newer worker's ID between those operations.
}

// CopyQ action(cmd) only imports clipboard text when cmd contains its percent-1
// placeholder. Keep the complete generated action free of that placeholder.
module.exports = function nativeNotificationSource() {
  const source = copyq([saveOnce.functionSource(), nativeSecretNotice.toString().replace(/\r\n/g, '\n')], ["secrets"]);
  if (source.includes('%1')) throw new Error('UNSAFE_NOTIFICATION_PLACEHOLDER');
  return source + '\nnativeSecretNotice';
};
