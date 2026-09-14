"use strict";


function isCode(text) { return /^\s*(?:import|export|var|const|let|function|class|def|package|using|namespace|#include|#!)\b/m.test(text) || /(?:=>|===|!==|&&|\|\|)/.test(text) || /\b(?:if|for|while|switch|catch)\s*\(/.test(text) || /\w+\s*\([^)]*\)\s*\{/.test(text); }

module.exports = { isCode: isCode };

