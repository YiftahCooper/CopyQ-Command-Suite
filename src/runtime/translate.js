"use strict";

const { copyq, script } = require("./command-source");

function translateBody() {
  return copyq([
    "var items = selectedItemsData(); var item = items.length ? items[0] : null; var textData = item && item[mimeText] ? item[mimeText] : input(); var text = str(textData);",
    "function translationFailure(reason) { notification('.id', 'translate-en', '.title', 'Translate to English', '.message', reason); abort(); } if (!text) translationFailure('TRANSLATE_EMPTY');",
    "var programFiles = str(env('ProgramFiles')).replace(/\\\\/g, '/'); var localAppData = str(env('LOCALAPPDATA')).replace(/\\\\/g, '/'); var helper = localAppData + '/CopyQCommandSuite/translation/Invoke-CopyQAzureTranslation.ps1'; var encodedText = str(toBase64(textData)); var result = null; try { result = execute('pwsh.exe', '-NoLogo', '-NoProfile', '-NonInteractive', '-File', helper, null, encodedText); } catch (e) {} if (!result || result.exit_code !== 0) { try { result = execute(programFiles + '/PowerShell/7/pwsh.exe', '-NoLogo', '-NoProfile', '-NonInteractive', '-File', helper, null, encodedText); } catch (e2) {} }",
    "if (!result || result.exit_code !== 0) { var reason = str(result && result.stderr).replace(/\\s+$/, ''); if (!/^(?:TRANSLATE_NOT_CONFIGURED|TRANSLATE_AUTH_FAILED|TRANSLATE_REGION_FAILED|TRANSLATE_RATE_LIMITED|TRANSLATE_FAILED|TRANSLATE_EMPTY)$/.test(reason)) reason = 'TRANSLATE_FAILED'; translationFailure(reason); } var encodedTranslation = str(result.stdout).replace(/\\s+$/, ''); var translated; try { translated = str(fromBase64(encodedTranslation)); } catch (e) { translationFailure('TRANSLATE_FAILED'); } if (!translated) translationFailure('TRANSLATE_EMPTY'); copy(mimeText, translated);",
  ], []);
}

module.exports = translateBody;

