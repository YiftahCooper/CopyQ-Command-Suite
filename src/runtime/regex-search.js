"use strict";

const { copyq, script } = require("./command-source");

function regexBody() { return copyq(["var query = dialog('Search'); if (!query) abort(); var checked = CopyQCore.validateRegex(query); if (!checked.ok) { notification('.id', 'regex', '.message', checked.reason); abort(); }", "var names = tab(); try { removeTab('Search'); } catch (e) {} tab('Search'); for (var t = 0; t < names.length; t += 1) { if (names[t] === 'Search') continue; tab(names[t]); for (var i = 0; i < size(); i += 1) { var item = getitem(i); if (checked.value.test(str(item[mimeText]))) { tab('Search'); insert(0, item); tab(names[t]); } } } tab('Search');"], ["regex"]); }

module.exports = regexBody;

