"use strict";

const { copyq, script } = require("./command-source");

function ocrBody() {
  return copyq([
    "var items = selectedItemsData(); var item = items.length ? items[0] : null; var png = item && item['image/png'] ? item['image/png'] : data('image/png'); if (!png || png.size() === 0) png = input();",
    "if (!png || png.size() === 0) { notification('.id', 'ocr', '.title', 'Copy Text in Image', '.message', 'OCR_NO_PNG'); abort(); }",
    "var programFiles = str(env('ProgramFiles')).replace(/\\\\/g, '/'); var candidates = [programFiles + '/Tesseract-OCR/tesseract.exe']; str(env('PATH')).split(';').forEach(function (directory) { directory = directory.replace(/^\\s*\"|\"\\s*$/g, '').replace(/\\\\/g, '/'); if (directory) candidates.push(directory + '/tesseract.exe'); });",
    "var executable = ''; for (var i = 0; i < candidates.length; ++i) { if (File(candidates[i]).exists()) { executable = candidates[i]; break; } } if (!executable) { notification('.id', 'ocr', '.title', 'Copy Text in Image', '.message', 'OCR_NOT_FOUND'); abort(); }",
    "var result = null; try { result = execute(executable, 'stdin', 'stdout', '-l', 'eng+heb', '--oem', '3', null, png); } catch (e) {}",
    "if (!result || result.exit_code !== 0) { notification('.id', 'ocr', '.title', 'Copy Text in Image', '.message', 'OCR_FAILED'); abort(); } var text = str(result.stdout).replace(/\\s+$/, ''); if (!text) { notification('.id', 'ocr', '.title', 'Copy Text in Image', '.message', 'OCR_NO_TEXT'); abort(); } copy(mimeText, text);",
  ], []);
}

module.exports = ocrBody;
