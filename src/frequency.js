"use strict";
const core = require("./core-node");
function FrequencyStore(state, maxEntries) { state = state || {}; this.maxEntries = maxEntries || 4096; this.state = { version: 2, counters: state.counters || {}, clock: state.clock || 0 }; this.legacy = state.frequent_usage_counts || {}; }
FrequencyStore.prototype.record = function (text) { var result = core.recordFrequency(this.state, this.legacy, text); var store = new FrequencyStore({ counters: result.state.counters, clock: result.state.clock, frequent_usage_counts: result.legacy }, this.maxEntries); store.prune(); return { store: store, count: result.result.count, promote: result.result.promote, hashes: result.result.hashes }; };
FrequencyStore.prototype.prune = function () { var keys = Object.keys(this.state.counters); var self = this; keys.sort(function (a, b) { return self.state.counters[a].lastUsed - self.state.counters[b].lastUsed; }); while (keys.length > this.maxEntries) delete this.state.counters[keys.shift()]; };
FrequencyStore.prototype.snapshot = function () { return { version: 2, counters: this.state.counters, clock: this.state.clock }; };
module.exports = { FrequencyStore: FrequencyStore, hashesFor: core.hashesFor, legacyKiloHash: core.legacyKiloHash, sortFrequent: core.sortFrequent };
