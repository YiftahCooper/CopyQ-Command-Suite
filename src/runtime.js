"use strict";

// Compatibility entry points; each command body has its own source file.
module.exports = {
  dispatcherBody: require("./runtime/clipboard-router"),
  undoableDeleteListenerBody: require("./runtime/move-to-trash"),
  undoDeleteBody: require("./runtime/undo-delete"),
  htmlSanitizerBody: require("./runtime/sanitize-html"),
  translateBody: require("./runtime/translate"),
  markdownBody: require("./runtime/render-markdown"),
  pygmentsBody: require("./runtime/highlight-code"),
  ocrBody: require("./runtime/ocr"),
  copyJsonBody: require("./runtime/copy-json"),
  pasteJsonBody: require("./runtime/paste-json"),
  regexBody: require("./runtime/regex-search"),
  titleBody: require("./runtime/title-case"),
  toggleBody: require("./runtime/toggle-case"),
  frequentBody: require("./runtime/show-frequent"),
  searchBody: require("./runtime/web-search"),
};
