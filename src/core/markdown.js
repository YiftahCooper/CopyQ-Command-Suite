"use strict";


function isMarkdown(value) {
  var text = String(value == null ? '' : value); var listItems;
  if (!text) return false;
  if (/(^|\n) {0,3}#{1,6}[ \t]+\S/.test(text)) return true;
  if (/(^|\n) {0,3}```[^\n]*\n[\s\S]*\n {0,3}```/.test(text)) return true;
  if (/\[[^\]\n]+\]\((?:https?:\/\/|\/|#|\.{0,2}\/)[^)]+\)/.test(text)) return true;
  if (/(^|\n) {0,3}>[ \t]+\S/.test(text)) return true;
  if (/(^|\n)\s*\|?.+\|.+\n\s*\|?\s*:?-{3,}:?\s*\|/.test(text)) return true;
  listItems = text.match(/(^|\n) {0,3}(?:[-+*]|\d+[.)])[ \t]+\S/g);
  return !!(listItems && listItems.length >= 2);
}

module.exports = { isMarkdown: isMarkdown };

