/* request and CopyQSetupPlan are supplied by the PowerShell host. No history API. */
(function () {
    // Normalize physical INI line endings before re-import. On Windows, a CR
    // before a multiline Command closing quote can otherwise become script data.
    // Intentional carriage returns in fields are escaped by exportCommands;
    // physical CRs here are Windows INI formatting, including the one before '"'.
    function native(items) { return str(exportCommands(items)).replace(/\r/g, ''); }
    function snapshot() {
        var current = commands();
        return { native: native(current), inventory: current.map(function (c) {
            return { id: c.internalId || '', name: c.name, automatic: !!c.automatic,
                local: c.shortcuts || [], global: c.globalShortcuts || [] };
        }) };
    }
    if (request.action === 'snapshot') return JSON.stringify(snapshot());
    if (request.action === 'helpers') {
        var verifiedCommands = commands();
        if (native(verifiedCommands) !== request.expected) throw new Error('COMMAND_STATE_CHANGED');
        var results = [];
        verifiedCommands.forEach(function (c) {
            if (request.ids.indexOf(c.internalId) < 0) return;
            var marker = '  return api;\n}());';
            var index = c.cmd.indexOf(marker);
            if (index < 0) return;
            var source = c.cmd.replace(/^copyq:\s*/, '');
            index = source.indexOf(marker);
            var core = (function () { eval(source.substring(0,index + marker.length)); return CopyQCore; }());
            var passed = true, exercised = false;
            if (core.inspectClipboard) { exercised=true; passed=core.inspectClipboard({text:'ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',formats:[]}).action==='ignored'; }
            if (core.route) { exercised=true; passed=passed && core.route({text:'https://example.org/',formats:[]}).action==='url'; }
            if (core.titleCase) { exercised=true; passed=passed && core.titleCase('hello world')==='Hello World'; }
            if (core.validateRegex) { exercised=true; passed=passed && !core.validateRegex('[').ok; }
            if (core.isMarkdown) { exercised=true; passed=passed && core.isMarkdown('# A heading'); }
            if (exercised) results.push({id:c.internalId,passed:!!passed});
        });
        return JSON.stringify(results);
    }
    if (request.action === 'preview') {
        var ids = CopyQSetupPlan.expandSelection(request.ids, request.catalog.map(function (c) { return c.id; }));
        var chosen = [];
        request.catalog.forEach(function (entry) { if (ids.indexOf(entry.id) >= 0) {
            var parsed = importCommands(entry.ini);
            if (parsed.length !== 1 || parsed[0].internalId !== entry.id) throw new Error('PACKAGE_IDENTITY_INVALID');
            chosen.push(parsed[0]);
        } });
        var plan = CopyQSetupPlan.plan(commands(), chosen, function (c) { return native([c]); }, request.shortcuts || {});
        var candidate = native(plan.commands); delete plan.commands;
        plan.before = native(commands()); plan.candidate = candidate; plan.selected = ids;
        return JSON.stringify(plan);
    }
    if (request.action === 'apply') {
        if (native(commands()) !== request.expected) throw new Error('COMMAND_STATE_CHANGED');
        var replacement = importCommands(request.candidate);
        setCommands(replacement);
        return JSON.stringify(snapshot());
    }
    throw new Error('UNKNOWN_SETUP_ACTION');
}());
