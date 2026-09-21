/* ES5: used directly by CopyQ and by Node tests. Native objects are retained. */
var CopyQSetupPlan = (function () {
    'use strict';
    var ROUTER = 'canonical.dispatcher', SECRET = 'canonical.secret-protection';
    function expandSelection(ids, known) {
        var result = [];
        function add(id) {
            if (known.indexOf(id) < 0) throw new Error('UNKNOWN_COMMAND');
            if (result.indexOf(id) < 0) result.push(id);
        }
        ids.forEach(add);
        if (result.indexOf('canonical.undo-delete') >= 0 || result.indexOf('canonical.undoable-delete-listener') >= 0) {
            add('canonical.undo-delete'); add('canonical.undoable-delete-listener');
        }
        if (result.indexOf('canonical.show-frequent') >= 0) add(ROUTER);
        if (result.indexOf(ROUTER) >= 0 && result.indexOf(SECRET) >= 0) throw new Error('PROTECTION_CONFLICT');
        return result;
    }
    function list(value) { return value ? (Array.isArray(value) ? value : [value]) : []; }
    // Read-only compatibility for the original companion wrappers. Matching the
    // complete known wrapper avoids adopting a same-name custom transformation.
    function commandIdentity(c) {
        if (c.internalId) return c.internalId;
        if (c.automatic || c.isScript || c.isGlobalShortcut === false) return '';
        var legacy = [
            ['Moonlander: Smart Title Case', 'smartTitleCase', 'f13', 'moonlander.smart-title', '\\{\\s*\\}'],
            ['Moonlander: Cycle Case', 'cycleCase', 'f19', 'moonlander.cycle-case', '\\{\\s*reselect\\s*:\\s*true\\s*\\}'],
            ['Moonlander: Transplant Hebrew-English', 'transplantHebrewEnglish', 'f22', 'moonlander.hebrew-layout', '\\{\\s*\\}']
        ];
        var shortcuts = list(c.globalShortcuts), i, rule, pattern;
        if (shortcuts.length !== 1) return '';
        for (i = 0; i < legacy.length; i += 1) {
            rule = legacy[i];
            if (c.name !== rule[0] || String(shortcuts[0]).toLowerCase() !== rule[2]) continue;
            pattern = new RegExp('^copyq:\\s*source\\(([' + "'\"" + '])([^' + "'\"" + '\\r\\n]+/MoonlanderTextTools)/transformations\\.js\\1\\);\\s*' +
                'source\\(\\1\\2/transaction\\.js\\1\\);\\s*MoonlanderTransaction\\.runTransaction\\(\\s*MoonlanderTransforms\\.' + rule[1] + '\\s*,\\s*' + rule[4] +
                '\\s*,\\s*MoonlanderTransaction\\.createCopyQAdapter\\(\\1\\2/Moonlander\\.Reselect\\.exe\\1\\)\\s*\\);?\\s*$');
            if (pattern.test(String(c.cmd || ''))) return rule[3];
        }
        return '';
    }
    function commandIdentities(items) {
        var seen = {};
        return items.map(function (c) {
            var id = commandIdentity(c);
            if (/^moonlander\./.test(id)) {
                if (seen[id]) throw new Error('DUPLICATE_IDENTITY');
                seen[id] = true;
            }
            return id;
        });
    }
    function plan(existing, chosen, serialize, overrides) {
        var selected = {}, seen = {}, added = [], updated = [], unchanged = [], removed = [];
        var existingIds = commandIdentities(existing);
        chosen = chosen.map(function (original) {
            var c = original, o = overrides[original.internalId];
            if (o) {
                c = {}; Object.keys(original).forEach(function (key) { c[key] = original[key]; });
                c.shortcuts = o.local; c.globalShortcuts = o.global; c.isGlobalShortcut = o.global.length > 0;
            }
            if (!c.internalId || selected[c.internalId]) throw new Error('DUPLICATE_IDENTITY');
            selected[c.internalId] = c; return c;
        });
        if (selected[ROUTER] && selected[SECRET]) throw new Error('PROTECTION_CONFLICT');
        var output = [], protection = selected[ROUTER] || selected[SECRET];
        existing.forEach(function (c, index) {
            var id = existingIds[index];
            if (protection && (id === ROUTER || id === SECRET) && id !== protection.internalId) {
                removed.push(id); return;
            }
            if (selected[id]) {
                if (seen[id]) throw new Error('DUPLICATE_IDENTITY');
                seen[id] = true;
                (serialize(c) === serialize(selected[id]) ? unchanged : updated).push(id);
                if (!protection || id !== protection.internalId) output.push(selected[id]);
            } else {
                chosen.forEach(function (n) { if (c.name === n.name) throw new Error('NAME_CONFLICT'); });
                output.push(c);
            }
        });
        chosen.forEach(function (c) {
            if (!seen[c.internalId]) { added.push(c.internalId); if (c !== protection) output.push(c); }
        });
        if (protection) output.unshift(protection);
        var shortcutOwners = {};
        output.forEach(function (c) {
            ['shortcuts', 'globalShortcuts'].forEach(function (kind) {
                list(c[kind]).forEach(function (shortcut) {
                    var key = kind + ':' + String(shortcut).replace(/\s/g,'').toLowerCase();
                    if (!String(shortcut).length) return;
                    var prior = shortcutOwners[key];
                    if (prior && (selected[c.internalId] || selected[prior.internalId])) throw new Error('SHORTCUT_CONFLICT');
                    shortcutOwners[key] = c;
                });
            });
        });
        return { commands: output, added: added, updated: updated, unchanged: unchanged,
            replacedProtection: removed, preserved: output.length - chosen.length,
            needsRestart: !!selected['canonical.undoable-delete-listener'] };
    }
    return { expandSelection: expandSelection, plan: plan, commandIdentities: commandIdentities };
}());
if (typeof module !== 'undefined') module.exports = CopyQSetupPlan;
