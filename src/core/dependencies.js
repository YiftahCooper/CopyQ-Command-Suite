"use strict";


function runDependency(execute, args) { var result = execute.apply(null, args || []); return result && result.exit_code === 0 ? { ok: true, value: result } : { ok: false, reason: 'DEPENDENCY_FAILED' }; }

module.exports = { runDependency: runDependency };

