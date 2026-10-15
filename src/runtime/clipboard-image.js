"use strict";

// CopyQ 16 can capture a browser blob URL as text and omit its binary image.
// Recover only the matching, still-current image into automatic-command data.
// This does not write the system clipboard or fetch the blob URL.
function restoreBrowserImage(formats, text) {
  if (!/^blob:https?:\/\/\S+$/i.test(text)) return '';
  if (formats.some(function (format) { return /^image\//i.test(format); })) return '';
  if (formats.indexOf(mimeOwner) >= 0 || formats.indexOf(mimeHidden) >= 0
      || CopyQCore.inspectClipboard({ text: '', formats: formats }).action === 'ignored') return '';
  if (CopyQCore.trim(str(data(mimeUriList))) !== text) return '';

  var nativePng = 'application/x-qt-windows-mime;value="PNG"';
  function matchesCurrentImage() {
    var currentFormats = str(clipboard('?')).split(/\r?\n/);
    return currentFormats.indexOf(mimeText) < 0
      && (currentFormats.indexOf('application/x-qt-image') >= 0 || currentFormats.indexOf(nativePng) >= 0)
      && currentFormats.indexOf(mimeOwner) < 0 && currentFormats.indexOf(mimeHidden) < 0
      && CopyQCore.inspectClipboard({ text: '', formats: currentFormats }).action !== 'ignored'
      && str(clipboard(mimeText)) === text
      && CopyQCore.trim(str(clipboard(mimeUriList))) === text;
  }
  function isPng(bytes) { return str(toBase64(bytes)).slice(0, 11) === 'iVBORw0KGgo'; }
  var matched = false;
  try {
    if (!matchesCurrentImage()) return '';
    matched = true;
    var bytes = clipboard(nativePng);
    if (!isPng(bytes)) bytes = clipboard('image/png');
    if (!matchesCurrentImage()) return 'failed';
    if (!isPng(bytes) || !setData('image/png', bytes)) return 'failed';
    return 'restored';
  } catch (e) {
    return matched ? 'failed' : '';
  }
}

module.exports = function clipboardImageSource() { return restoreBrowserImage.toString().replace(/\r\n/g, '\n'); };
