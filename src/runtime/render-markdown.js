"use strict";

const { copyq, script } = require("./command-source");

function markdownBody() { return copyq(["var text = data(mimeText); if (!text || !CopyQCore.isMarkdown(str(text))) abort();", "var appData = str(env('APPDATA')).replace(/\\\\/g, '/'); var result = null; try { result = execute('marked.cmd', null, text); } catch (e) {} if (!result || result.exit_code !== 0) { try { result = execute(appData + '/npm/marked.cmd', null, text); } catch (e2) {} }", "if (!result || result.exit_code !== 0) { notification('.id', 'markdown', '.message', 'MARKDOWN_FAILED'); abort(); } setData(mimeHtml, result.stdout);"], ["markdown"]); }

module.exports = markdownBody;

