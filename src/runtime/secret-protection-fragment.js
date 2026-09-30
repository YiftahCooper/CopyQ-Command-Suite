"use strict";

const nativeNotificationSource = require("./secret-native-notification");

// One safety boundary reused by the router and standalone protection command.
// Only the classifier differs; Windows clipboard writes are never performed.
function protectionLines(classifier, destinationExpression = "''") {
  return [
    "function secretNotice(reason, original, destination) { var id; try { if (typeof sha256sum === 'function' && CopyQCore.canSaveProtectedOnce({text:str(original),formats:formats,mimeOwner:mimeOwner,mimeHidden:mimeHidden})) { var previous=str(settings('secret_notification_current')); id='copyq-secret-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2); var request={id:id,previous:previous,expected:str(sha256sum(original)),reason:reason,destination:destination}; settings('secret_notification_current',id); action(" + JSON.stringify(nativeNotificationSource()) + " + '(' + JSON.stringify(request) + ');'); return; } } catch(e) { reason += '\\nSAVE_UNAVAILABLE'; } try { notification('.id','secret-protection','.title','Clipboard protection','.message',reason,'.time',7000); } catch(e) {} }",
    "var handlers = commands().filter(function (c) { return c.automatic && (c.internalId === 'canonical.dispatcher' || c.internalId === 'canonical.secret-protection'); }); if (handlers.length > 1) { try { notification('.id', 'secret-conflict', '.message', 'SECRET_HANDLER_CONFLICT'); } finally { ignore(); } abort(); }",
    "var formats = dataFormats(); var textData = data(mimeText); var text = str(textData);",
    "var routed = CopyQCore." + classifier + "({ text: text, formats: formats, mimeOwner: mimeOwner, mimeHidden: mimeHidden });",
    "if (routed.action === 'ignored') { try { secretNotice('SECRET_IGNORED',textData); } finally { ignore(); } abort(); } if (routed.action === 'passthrough' && !routed.frequencyEligible) abort(); if (!textData) abort();",
    "if (routed.redactedText !== undefined) { var originalForNotice=textData; try { for (var i = 0; i < formats.length; i += 1) { if (formats[i] !== mimeOutputTab && formats[i] !== 'application/x-copyq-clipboard-mode') removeData(formats[i]); } if (!setData(mimeText, routed.redactedText)) throw new Error('REDACTION_WRITE_FAILED'); text = routed.redactedText; textData = data(mimeText); } catch (error) { try { notification('.id', 'secret-ignore', '.message', 'SECRET_REDACTION_FAILED', '.time', 7000); } finally { ignore(); } abort(); } secretNotice('SECRET_REDACTED',originalForNotice," + destinationExpression + "); originalForNotice=null; }",
  ];
}

module.exports = protectionLines;

