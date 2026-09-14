"use strict";

// One safety boundary reused by the router and standalone protection command.
// Only the classifier differs; Windows clipboard writes are never performed.
function protectionLines(classifier) {
  return [
    "var handlers = commands().filter(function (c) { return c.automatic && (c.internalId === 'canonical.dispatcher' || c.internalId === 'canonical.secret-protection'); }); if (handlers.length > 1) { try { notification('.id', 'secret-conflict', '.message', 'SECRET_HANDLER_CONFLICT'); } finally { ignore(); } abort(); }",
    "var formats = dataFormats(); var textData = data(mimeText); var text = str(textData);",
    "var routed = CopyQCore." + classifier + "({ text: text, formats: formats, mimeOwner: mimeOwner, mimeHidden: mimeHidden });",
    "if (routed.action === 'ignored') { try { notification('.id', 'secret-ignore', '.title', 'Ignoring secret in the clipboard', '.message', 'SECRET_IGNORED'); } finally { ignore(); } abort(); } if (routed.action === 'passthrough' && !routed.frequencyEligible) abort(); if (!textData) abort();",
    "if (routed.redactedText !== undefined) { try { for (var i = 0; i < formats.length; i += 1) { if (formats[i] !== mimeOutputTab && formats[i] !== 'application/x-copyq-clipboard-mode') removeData(formats[i]); } if (!setData(mimeText, routed.redactedText)) throw new Error('REDACTION_WRITE_FAILED'); text = routed.redactedText; textData = data(mimeText); } catch (error) { try { notification('.id', 'secret-ignore', '.message', 'SECRET_REDACTION_FAILED'); } finally { ignore(); } abort(); } try { notification('.id', 'secret-redacted', '.title', 'Secrets removed from history', '.message', 'SECRET_REDACTED'); } catch (noticeError) {} }",
  ];
}

module.exports = protectionLines;

