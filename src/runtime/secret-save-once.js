"use strict";

const { copyq } = require("./command-source");

// This ES5 function is embedded in a notification action for either protection
// variant. It uses CopyQ APIs, not Node or a runtime path into this repository.
function saveProtectedClipboardOnce(expected, isCurrent, routedDestination) {
  function notice(reason) {
    try { notification('.id', 'secret-save-once', '.title', 'Save to history', '.message', reason, '.time', 7000); } catch (e) {}
  }
  function currentValue() {
    var value = clipboard(mimeText);
    var formats = str(clipboard('?')).split(/\r?\n/);
    if ((isCurrent && !isCurrent()) || !/^[0-9a-f]{64}$/.test(expected)
        || str(sha256sum(value)) !== expected
        || !CopyQCore.canSaveProtectedOnce({ text: str(value), formats: formats, mimeOwner: mimeOwner, mimeHidden: mimeHidden })) return null;
    return value;
  }
  var originalTab;
  try {
    if (currentValue() === null) { notice('SECRET_SAVE_EXPIRED'); return; }
    var confirmed = dialog('.title', 'Save to history?', '.label',
      'Store this item unredacted in clipboard history?<br><br>' +
      'You can reuse it normally afterward. This does not create an exception for future copies from other applications.<br><br>' +
      'The saved item may also be retained in trash or backups.', '.onTop', true);
    if (confirmed !== true) return;
    // Re-read after the dialog: never keep the pre-confirmation plaintext as a
    // fallback if the user copied something else while deciding.
    var value = currentValue();
    if (value === null) { notice('SECRET_SAVE_EXPIRED'); return; }
    originalTab = selectedTab();
    var destination = routedDestination || str(config('clipboard_tab'));
    if (!destination || (routedDestination && tab().indexOf(destination) < 0)) { notice('SECRET_SAVE_FAILED'); return; }
    tab(destination);
    var item = {};
    item[mimeText] = value;
    insert(0, item);
    value = null;
  } catch (e) {
    notice('SECRET_SAVE_FAILED');
    return;
  } finally {
    if (originalTab !== undefined) { try { tab(originalTab); } catch (e) {} }
  }
  notice('SECRET_SAVED_ONCE');
}

module.exports = function saveOnceAction() {
  return copyq(['(' + saveProtectedClipboardOnce.toString().replace(/\r\n/g, '\n') + ')(str(input()));'], ["secrets"]);
};
module.exports.functionSource = function () { return saveProtectedClipboardOnce.toString().replace(/\r\n/g, '\n'); };
