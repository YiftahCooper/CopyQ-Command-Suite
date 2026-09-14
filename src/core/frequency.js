"use strict";

var common = require("./common");
var trim = common.trim;

function fnv1a(text) { var hash = 2166136261; var i; for (i = 0; i < text.length; i += 1) { hash ^= text.charCodeAt(i); hash = (hash * 16777619) >>> 0; } return (hash >>> 0).toString(16); }
function djb2(text) { var hash = 5381; var i; for (i = 0; i < text.length; i += 1) hash = ((hash << 5) + hash + text.charCodeAt(i)) | 0; return (hash >>> 0).toString(36); }
function legacyKiloHash(text) { text = String(text == null ? '' : text); return text.length + '_' + djb2(text); }
function normalizeFrequencyText(text) { return trim(text); }
function v2HashesFor(text) { text = String(text == null ? '' : text); return { version: 2, first: fnv1a(text), second: djb2(text), key: 'v2:' + fnv1a(text) + ':' + djb2(text) }; }
function hashesFor(text) { text = normalizeFrequencyText(text); return { version: 3, first: fnv1a(text), second: djb2(text), key: 'v3:' + fnv1a(text) + ':' + djb2(text) }; }
function cloneCounters(counters) { var copy = {}; var key; for (key in counters || {}) if (Object.prototype.hasOwnProperty.call(counters, key)) copy[key] = { version: counters[key].version, first: counters[key].first, second: counters[key].second, count: counters[key].count, lastUsed: counters[key].lastUsed }; return copy; }
function pruneCounters(state, maximum) {
  var keys = []; var key;
  for (key in state.counters) if (Object.prototype.hasOwnProperty.call(state.counters, key)) keys.push(key);
  keys.sort(function (a, b) { return (state.counters[a].lastUsed - state.counters[b].lastUsed) || (a < b ? -1 : 1); });
  while (keys.length > maximum) delete state.counters[keys.shift()];
}
function recordFrequency(state, v2State, legacy, text) {
  var next = { version: 3, counters: cloneCounters((state || {}).counters), clock: Number((state || {}).clock || 0) };
  var canonicalText = normalizeFrequencyText(text); var hash = hashesFor(canonicalText); var oldHash = v2HashesFor(canonicalText); var oldKey = legacyKiloHash(canonicalText); var entry; var imported = 0;
  if (!canonicalText) return { state: next, result: { count: 0, promote: false, key: '', canonicalText: '', hashes: hash } };
  entry = next.counters[hash.key];
  if (!entry) {
    if (v2State && v2State.counters && v2State.counters[oldHash.key]) imported += Number(v2State.counters[oldHash.key].count || 0);
    if (legacy && legacy[oldKey] !== undefined) imported += Number(legacy[oldKey] || 0);
    entry = { version: 3, first: hash.first, second: hash.second, count: imported, lastUsed: 0 };
  }
  entry.count += 1; entry.lastUsed = ++next.clock; next.counters[hash.key] = entry;
  pruneCounters(next, 4096);
  return { state: next, result: { count: entry.count, promote: entry.count >= 6, key: hash.key, canonicalText: canonicalText, hashes: hash } };
}
function dismissFrequency(state, key) {
  var next = { version: 3, counters: cloneCounters((state || {}).counters), clock: Number((state || {}).clock || 0) }; var entry = next.counters[key]; var parts = String(key || '').split(':'); var savedCount = 0;
  if (!entry) entry = { version: 3, first: parts[1] || '', second: parts[2] || '', count: 0, lastUsed: 0 };
  savedCount = Number(entry.count || 0); entry.count = 0; entry.lastUsed = ++next.clock; next.counters[key] = entry; pruneCounters(next, 4096);
  return { state: next, savedCount: savedCount };
}
function restoreFrequency(state, key, savedCount) {
  var next = { version: 3, counters: cloneCounters((state || {}).counters), clock: Number((state || {}).clock || 0) }; var parts = String(key || '').split(':'); var entry = next.counters[key];
  if (!entry) entry = { version: 3, first: parts[1] || '', second: parts[2] || '', count: 0, lastUsed: 0 };
  entry.count = Number(entry.count || 0) + Number(savedCount || 0); entry.lastUsed = ++next.clock; next.counters[key] = entry; pruneCounters(next, 4096);
  return { state: next, count: entry.count };
}
function sortFrequent(items) { return items.slice().sort(function (a, b) { return (b.count - a.count) || (a.order - b.order); }); }

module.exports = { legacyKiloHash: legacyKiloHash, normalizeFrequencyText: normalizeFrequencyText, v2HashesFor: v2HashesFor, hashesFor: hashesFor, recordFrequency: recordFrequency, dismissFrequency: dismissFrequency, restoreFrequency: restoreFrequency, sortFrequent: sortFrequent };

