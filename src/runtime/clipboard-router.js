"use strict";

const { copyq } = require("./command-source");
const protectionLines = require("./secret-protection-fragment");

function dispatcherBody() {
  return copyq([
    "var LEGACY_KEY = 'frequent_usage_counts'; var V2_KEY = 'frequent_usage_counts_v2'; var V3_KEY = 'frequent_usage_counts_v3'; var FREQ_KEY_MIME = 'application/x-copyq-user-frequency-key'; var FREQ_COUNT_MIME = 'application/x-copyq-user-frequency-count';",
    "function settingsObject(key, fallback) { try { var value = settings(key); return value ? JSON.parse(value) : fallback; } catch (e) { return fallback; } }",
  ].concat(protectionLines("route"), [
    "var frequency = null; if (routed.frequencyEligible) { var state = settingsObject(V3_KEY, { version: 3, counters: {}, clock: 0 }); var v2 = settingsObject(V2_KEY, { version: 2, counters: {}, clock: 0 }); var legacy = settingsObject(LEGACY_KEY, {}); frequency = CopyQCore.recordFrequency(state, v2, legacy, text); settings(V3_KEY, JSON.stringify(frequency.state)); }",
    "if (frequency && frequency.result.promote) { var originalTab = selectedTab(); var key = frequency.result.key; var frequentItem = {}; frequentItem[mimeText] = frequency.result.canonicalText; frequentItem[FREQ_KEY_MIME] = key; frequentItem[FREQ_COUNT_MIME] = String(frequency.result.count); var escapedKey = key.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&'); tab('Frequent'); var existing = ItemSelection('Frequent').select(new RegExp('^' + escapedKey + '$'), FREQ_KEY_MIME); if (existing.length) { existing.setItemAtIndex(0, frequentItem); existing.move(0); } else { insert(0, frequentItem); } tab(originalTab); }",
    "if (routed.action === 'big') { setData(mimeOutputTab, 'BIG'); abort(); } if (routed.action === 'url') { setData(mimeOutputTab, '&URLs'); abort(); } if (routed.action === 'artifacts') { setData(mimeOutputTab, 'Artifacts'); abort(); } if (routed.action === 'code') { setData(mimeOutputTab, 'Code'); abort(); } if (routed.action === 'passthrough') abort();",
  ]), ["routing", "frequency"]);
}

module.exports = dispatcherBody;
