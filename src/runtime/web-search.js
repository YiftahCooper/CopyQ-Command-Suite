"use strict";

const { copyq, script } = require("./command-source");

function searchBody() { return copyq(["if (!copy()) abort(); var text = str(clipboard()); if (!text) abort(); var engines = [{ name: 'DuckDuckGo', url: 'https://duckduckgo.com/?q=%s' }, { name: 'GitHub', url: 'https://github.com/search?q=%s' }]; var items = []; for (var i = 0; i < engines.length; i += 1) { var item = {}; item[mimeText] = engines[i].name; items.push(item); } var chosen = menuItems(items); if (chosen < 0) abort(); var url = engines[chosen].url.replace('%s', encodeURIComponent(text)); open(url);"], []); }

module.exports = searchBody;

