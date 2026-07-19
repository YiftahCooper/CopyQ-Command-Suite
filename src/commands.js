"use strict";

const runtime = require("./runtime");

function command(internalId, name, cmd, options) {
  const settings = options || {};
  return { internalId, name, cmd, automatic: !!settings.automatic, isScript: false, inMenu: settings.inMenu !== false, input: settings.input || "text/plain", display: settings.display === true, isGlobalShortcut: (settings.globalShortcuts || []).length > 0, globalShortcuts: settings.globalShortcuts || [] };
}

function buildCandidate() {
  return { schema: 2, commands: [
    command("canonical.dispatcher", "Canonical Dispatcher", runtime.dispatcherBody(), { automatic: true, inMenu: false, display: false }),
    command("canonical.html-sanitizer", "Remove Background and Text Colors", runtime.htmlSanitizerBody(), { automatic: true, input: "text/html" }),
    command("canonical.translate-en", "Translate to English", runtime.translateBody()),
    command("canonical.markdown-render", "Render Markdown", runtime.markdownBody(), { automatic: true }),
    command("canonical.pygments-highlight", "Highlight Code", runtime.pygmentsBody()),
    command("canonical.ocr", "Copy Text in Image", runtime.ocrBody(), { input: "image/png", globalShortcuts: ["meta+ctrl+t"] }),
    command("canonical.copy-json", "Copy Items as JSON", runtime.copyJsonBody()),
    command("canonical.paste-json", "Paste Items from JSON", runtime.pasteJsonBody()),
    command("canonical.regex-search", "Search All Tabs", runtime.regexBody()),
    command("canonical.smart-title", "To Title Case", runtime.titleBody()),
    command("canonical.toggle-case", "Toggle Upper/Lower Case", runtime.toggleBody()),
    command("canonical.show-frequent", "Show Frequent", runtime.frequentBody(), { globalShortcuts: ["meta+shift+f"] }),
    command("canonical.copy-and-search", "Copy and Search on Web", runtime.searchBody()),
  ] };
}

function stableStringify(value) {
  if (Array.isArray(value)) return "[" + value.map(stableStringify).join(",") + "]";
  if (value && typeof value === "object") return "{" + Object.keys(value).sort().map((key) => JSON.stringify(key) + ":" + stableStringify(value[key])).join(",") + "}";
  return JSON.stringify(value);
}

module.exports = { buildCandidate, stableStringify };
