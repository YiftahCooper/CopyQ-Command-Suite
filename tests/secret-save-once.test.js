"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const test = require("node:test");
const vm = require("node:vm");
const { buildCandidate, buildSecretProtection } = require("../src/commands");
const secrets = require("../src/core/secrets");
const uuid = "123e4567-e89b-42d3-a456-426614174000";
const digest = (text) => crypto.createHash("sha256").update(text).digest("hex");
const mixed = '{"message":"Synthetic example","api_key":"' + uuid + '"}';

function dispatch(command, text = uuid, extraFormats = [], options = {}) {
  const notices = []; const actions = []; const state = {}; let ignored = false; const stop = {};
  const values = { "text/plain": text };
  const context = {
    commands: () => [command], str: String, mimeText: "text/plain", mimeOwner: "owner", mimeHidden: "hidden",
    mimeOutputTab: 'output-tab',
    dataFormats: () => ["text/plain", ...extraFormats], data: (mime) => values[mime],
    removeData: (mime) => { delete values[mime]; }, setData: (mime, value) => { values[mime] = value; return true; },
    sha256sum: digest, notification: (...args) => notices.push(args),
    action: (cmd) => { if (options.actionFails) throw Error('launch failed'); actions.push(cmd); },
    ignore: () => { ignored = true; }, abort: () => { throw stop; },
    settings: (key, value) => { assert.equal(key, 'secret_notification_current'); if (value !== undefined) state[key] = value; return state[key] || ''; },
  };
  try { vm.runInNewContext(command.cmd.replace(/^copyq:\s*/, ""), context); } catch (e) { if (e !== stop) throw e; }
  return { notices, actions, state, values, ignored };
}

function actionFrom(command) {
  // Test the save function independently of notification delivery.
  return { code: require('../src/runtime/secret-save-once')().replace(/^copyq:\s*/, ''), input: digest(uuid) };
}

function runAction(action, options = {}) {
  const saved = []; const notices = []; let selected = "Unrelated Tab"; let confirmations = 0;
  let text = options.text === undefined ? uuid : options.text;
  let formats = options.formats || ["text/plain", "text/html"];
  const context = {
    str: String, mimeText: "text/plain", mimeOwner: "owner", mimeHidden: "hidden", sha256sum: digest,
    input: () => action.input,
    clipboard: (format) => format === "?" ? formats.join("\n") + "\n" : text,
    dialog: (...args) => {
      confirmations += 1;
      assert.equal(JSON.stringify(args).includes(uuid), false, "confirmation must not reveal the secret");
      if (options.afterDialog !== undefined) text = options.afterDialog;
      if (options.formatsAfterDialog) formats = options.formatsAfterDialog;
      return Object.hasOwn(options, "confirm") ? options.confirm : true;
    },
    notification: (...args) => notices.push(args),
    config: (key) => { assert.equal(key, "clipboard_tab"); return options.historyDisabled ? "" : "My Clipboard"; },
    selectedTab: () => selected, tab: (name) => { if (name === undefined) return ["My Clipboard", "Unrelated Tab"]; selected = name; },
    insert: (row, item) => { if (options.writeFails) throw new Error("private failure " + uuid); saved.push({ row, tab: selected, item: JSON.parse(JSON.stringify(item)) }); },
    settings: () => assert.fail("one-time save must not persist an exception or count copies"),
    copy: () => assert.fail("one-time save must not change the immediate-paste clipboard"),
  };
  vm.runInNewContext(action.code, context);
  return { saved, notices, selected, confirmations, text };
}

test("one-time override eligibility is limited to heuristic secrets", () => {
  assert.equal(typeof secrets.canSaveIgnoredOnce, "function");
  for (const text of [uuid, "ExamplePass123!", "a1b2".repeat(16)]) {
    assert.equal(secrets.canSaveIgnoredOnce({ text }), true, text);
  }
  for (const text of ["Collegiate", "ghp_" + "a".repeat(36), "API_KEY=" + uuid, "MYTOKEN=" + uuid, "Authorization: Bearer " + uuid, "https://example.test/?api_key=" + uuid]) {
    assert.equal(secrets.canSaveIgnoredOnce({ text }), false, text);
  }
  for (const format of ["Clipboard Viewer Ignore", "image/png", "owner", "hidden"]) {
    assert.equal(secrets.canSaveIgnoredOnce({ text: uuid, formats: [format], mimeOwner: "owner", mimeHidden: "hidden" }), false);
  }
});

test("both protection variants asynchronously offer ignored and redacted saves without passing original content", () => {
  const router = buildCandidate().commands[0];
  const standalone = buildSecretProtection();
  for (const command of [router, standalone]) {
    for (const text of [uuid, mixed]) {
      const result = dispatch(command, text);
      assert.equal(result.actions.length, 1);
      assert.equal(result.notices.length, 0, 'no duplicate custom toast');
      assert.equal(result.ignored, text === uuid);
      assert.ok(result.actions[0].includes(digest(text)), 'fingerprint covers the ORIGINAL, not sanitized text');
      assert.ok(!result.actions[0].includes(uuid));
      assert.ok(!result.actions[0].includes('%1'), 'CopyQ must not substitute clipboard text into the action');
      if (text === mixed) assert.ok(result.values['text/plain'].includes('[REDACTED]'));
    }
    for (const [text, formats] of [["ghp_" + "a".repeat(36), []], [uuid, ["Clipboard Viewer Ignore"]], [mixed, ['hidden']]]) {
      const result = dispatch(command, text, formats);
      assert.equal(result.actions.length, 0);
      assert.equal(result.notices[0].includes('.button'), false);
      assert.equal(result.notices[0][result.notices[0].indexOf('.time') + 1], 7000);
    }
  }
});

test('redacted mixed text can be explicitly saved but concealed and internal data cannot', () => {
  const action = { ...actionFrom(buildSecretProtection()), input: digest(mixed) };
  const result = runAction(action, { text: mixed });
  assert.equal(result.confirmations, 1);
  assert.equal(result.saved[0]?.item['text/plain'], mixed);
  for (const format of ['Clipboard Viewer Ignore', 'hidden', 'owner', 'image/png']) {
    assert.deepEqual(runAction(action, { text: mixed, formats: ['text/plain', format] }).saved, []);
  }
});

function runNativeWorker(options = {}) {
  const text = options.text || uuid;
  const dispatched = dispatch(options.command || buildSecretProtection(), text);
  assert.equal(dispatched.actions.length, 1, 'native worker must be scheduled');
  const saved = []; const savedTabs = []; const calls = []; const notices = []; let confirmations = 0; let reads = 0;
  let selected = 'Original';
  const iconBytes = Buffer.from('synthetic icon bytes');
  let iconWritten; let iconRemoved = false;
  const state = dispatched.state;
  const context = {
    str: String, mimeText: 'text/plain', mimeOwner: 'owner', mimeHidden: 'hidden',
    info: (key) => { assert.equal(key, 'exe'); return 'D:/Portable Tools/CopyQ/copyq.exe'; },
    File: function (path) {
      this.exists = () => !options.missingHelper;
      this.openReadOnly = () => path === ':/images/logo.png' && !options.missingIcon;
      this.readAll = () => iconBytes;
      this.size = () => iconBytes.length;
      this.close = () => {};
    },
    Dir: function () { return { tempPath: () => 'D:/Temporary Files' }; },
    TemporaryFile: function () {
      this.open = () => !options.iconWriteFails;
      this.write = (bytes) => { iconWritten = bytes; return bytes.length; };
      this.close = () => {};
      this.fileName = () => 'D:/Temporary Files/copyq-toast-123.png';
      this.remove = () => { iconRemoved = true; return true; };
    },
    settings: (key, value) => {
      if (value !== undefined) state[key] = value;
      const result = state[key] || '';
      if (value === undefined && ++reads === 4 && options.supersedeAtCleanup) state[key] = 'newer-notification';
      return result;
    },
    execute: (...args) => {
      calls.push(args);
      if (args.includes('-close')) return { exit_code: 0, stdout: '', stderr: '' };
      if (args.includes('-p')) {
        assert.equal(iconWritten, iconBytes, 'write CopyQ resource bytes, not clipboard content');
        assert.equal(iconRemoved, false, 'icon must exist until helper exits');
      }
      if (options.newerNotice) state.secret_notification_current = 'newer-notification';
      if (options.failure) throw Error('synthetic launch error');
      return { exit_code: options.exitCode === undefined ? 0 : options.exitCode, stdout: '', stderr: '' };
    },
    clipboard: (format) => format === '?' ? 'text/plain\n' : (options.stale ? 'different' : text),
    sha256sum: digest,
    dialog: () => { confirmations++; if (options.newerDuringDialog) state.secret_notification_current = 'newer'; return options.cancel ? undefined : true; },
    notification: (...args) => notices.push(args),
    selectedTab: () => selected,
    tab: (name) => { if (name === undefined) return options.tabs || ['Main', 'Original', 'Artifacts', 'BIG', 'Code', '&URLs']; selected = name; },
    config: () => 'Main',
    insert: (row, item) => { saved.push(item); savedTabs.push(selected); },
  };
  vm.runInNewContext(dispatched.actions[0].replace(/^copyq:\s*/, ''), context);
  return { saved, savedTabs, selected, calls, confirmations, notices, state, iconRemoved, primaryTab: dispatched.values['output-tab'] };
}

test('native notices use the installed CopyQ icon and clean it up on click, dismissal, timeout and error', () => {
  for (const command of [buildCandidate().commands[0], buildSecretProtection()]) {
    for (const options of [{}, { exitCode: 2 }, { exitCode: 3 }, { failure: true }]) {
      const result = runNativeWorker({ command, ...options });
      const launch = result.calls.find(args => args.includes('-t'));
      assert.ok(launch.includes('-p'), 'supply the CopyQ image instead of the SnoreToast default');
      assert.equal(launch[launch.indexOf('-p') + 1], 'D:/Temporary Files/copyq-toast-123.png');
      assert.equal(result.iconRemoved, true);
      assert.equal(result.saved.length, options.exitCode || options.failure ? 0 : 1);
    }
  }
});

test('unavailable icon does not disable native notifications or confirmed saving', () => {
  for (const options of [{ missingIcon: true }, { iconWriteFails: true }]) {
    const result = runNativeWorker(options);
    assert.equal(result.calls.find(args => args.includes('-t')).includes('-p'), false);
    assert.equal(result.saved.length, 1);
  }
});

test('router confirmation preserves the redacted item destination, while standalone saves use main history', () => {
  const router = buildCandidate().commands[0];
  for (const [text, destination] of [
    [mixed, 'Artifacts'],
    [mixed + '\n' + 'Ordinary text. '.repeat(400), 'BIG'],
    ['https://example.test/?api_key=' + uuid, '&URLs'],
    ['function example() {\n  const api_key = "' + uuid + '";\n  return api_key;\n}', 'Code'],
    ['Here is the access information: api_key=' + uuid + '\nKeep this private.', 'Main'],
    [uuid, 'Main'],
  ]) {
    const result = runNativeWorker({ command: router, text });
    assert.equal(result.primaryTab || 'Main', destination, 'fixture primary route');
    assert.deepEqual(result.savedTabs, [destination], 'confirmed original must follow the same route');
    assert.equal(result.saved[0]['text/plain'], text);
    assert.equal(result.selected, 'Original');
    assert.deepEqual(runNativeWorker({ text }).savedTabs, ['Main'], 'standalone must remain routing-free');
  }
});

test('a removed routed destination fails safely instead of saving into the main tab', () => {
  const result = runNativeWorker({ command: buildCandidate().commands[0], text: mixed, tabs: ['Main', 'Original'] });
  assert.deepEqual(result.saved, []);
  assert.equal(result.selected, 'Original');
  assert.match(JSON.stringify(result.notices), /SECRET_SAVE_FAILED/);
});

test('native body click alone opens confirmation; dismiss, timeout and failures never save', () => {
  for (const text of [uuid, mixed]) {
    const result = runNativeWorker({ text });
    assert.equal(result.confirmations, 1);
    assert.equal(result.saved[0]['text/plain'], text);
    const launch = result.calls.find(args => args.includes('-t'));
    assert.equal(launch[0], 'D:/Portable Tools/CopyQ/snoretoast.exe');
    assert.equal(launch[launch.indexOf('-appID') + 1], 'copyq');
    assert.equal(launch[launch.indexOf('-d') + 1], 'short');
    assert.ok(!JSON.stringify(result.calls).includes(uuid));
    assert.ok(!JSON.stringify(result.calls).includes(digest(text)), 'no fingerprint sent to Windows helper');
    assert.ok(result.calls.some(args => args.includes('-close')), 'expired toast must be cleaned up');
    assert.match(result.state.secret_notification_current, /^copyq-secret-/);
  }
  for (const options of [{ exitCode: 1 }, { exitCode: 2 }, { exitCode: 3 }, { exitCode: -1 }, { failure: true }, { missingHelper: true }, { stale: true }, { newerNotice: true }]) {
    const result = runNativeWorker(options);
    assert.equal(result.confirmations, 0, JSON.stringify(options));
    assert.equal(result.saved.length, 0);
  }
  for (const options of [{ cancel: true }, { newerDuringDialog: true }]) {
    const result = runNativeWorker(options);
    assert.equal(result.confirmations, 1);
    assert.equal(result.saved.length, 0);
  }
});

test('an old worker cannot clear a newer request arriving between ownership read and cleanup', () => {
  const result = runNativeWorker({ exitCode: 2, supersedeAtCleanup: true });
  // Either there is no final ownership read at all, or the concurrent writer
  // wins. In neither case may the finishing worker erase the latest ID.
  assert.notEqual(result.state.secret_notification_current, '');
  assert.equal(result.saved.length, 0);
});

test('worker dispatch failure cannot break exclusion or redaction', () => {
  for (const text of [uuid, mixed]) {
    const result = dispatch(buildSecretProtection(), text, [], { actionFails: true });
    assert.equal(result.ignored, text === uuid);
    if (text === mixed) assert.ok(result.values['text/plain'].includes('[REDACTED]'));
    assert.ok(JSON.stringify(result.notices).includes('SAVE_UNAVAILABLE'));
  }
});

test("confirmed save writes a normal plain-text history item without changing clipboard or frequency", () => {
  const action = actionFrom(buildSecretProtection());
  const result = runAction(action);
  assert.equal(result.confirmations, 1);
  assert.deepEqual(result.saved, [{ row: 0, tab: "My Clipboard", item: { "text/plain": uuid } }]);
  assert.equal(result.selected, "Unrelated Tab");
  assert.equal(result.text, uuid);
  assert.match(JSON.stringify(result.notices), /SECRET_SAVED_ONCE/);
  assert.equal(JSON.stringify(result.notices).includes(uuid), false);
  assert.equal(secrets.inspectClipboard({ text: uuid }).action, "ignored", "saving must not create an exemption for future copies");
});

test("cancel or closing the confirmation saves nothing", () => {
  const action = actionFrom(buildSecretProtection());
  for (const confirm of [undefined, false, null, ""]) {
    const result = runAction(action, { confirm });
    assert.equal(result.confirmations, 1);
    assert.deepEqual(result.saved, []);
    assert.deepEqual(result.notices, []);
  }
});

test("stale notifications cannot save replacement clipboard content before or during confirmation", () => {
  const action = actionFrom(buildSecretProtection());
  for (const options of [{ text: "OtherPass123!" }, { afterDialog: "OtherPass123!" }, { text: uuid + " " }]) {
    const result = runAction(action, options);
    assert.equal(result.confirmations, options.afterDialog ? 1 : 0);
    assert.deepEqual(result.saved, []);
    assert.match(JSON.stringify(result.notices), /SECRET_SAVE_EXPIRED/);
  }
});

test("current concealment, image and ownership metadata block a matching text fingerprint", () => {
  const action = actionFrom(buildSecretProtection());
  for (const format of ["Clipboard Viewer Ignore", "image/png", "owner", "hidden"]) {
    for (const options of [{ formats: ["text/plain", format] }, { formatsAfterDialog: ["text/plain", format] }]) {
      const result = runAction(action, options);
      assert.deepEqual(result.saved, []);
      assert.match(JSON.stringify(result.notices), /SECRET_SAVE_EXPIRED/);
    }
  }
});

test("a missing, malformed or mismatched fingerprint cannot open confirmation or write history", () => {
  const action = actionFrom(buildSecretProtection());
  for (const input of ["", "not-a-digest", "a".repeat(64)]) {
    const result = runAction({ ...action, input });
    assert.equal(result.confirmations, 0);
    assert.deepEqual(result.saved, []);
    assert.match(JSON.stringify(result.notices), /SECRET_SAVE_EXPIRED/);
  }
});

test("save failures restore script tab and report no raw text or exception detail", () => {
  const result = runAction(actionFrom(buildSecretProtection()), { writeFails: true });
  assert.equal(result.selected, "Unrelated Tab");
  assert.deepEqual(result.saved, []);
  assert.match(JSON.stringify(result.notices), /SECRET_SAVE_FAILED/);
  assert.equal(JSON.stringify(result.notices).includes(uuid), false);
});

test("disabled main history never redirects an explicit save to an unrelated tab", () => {
  const result = runAction(actionFrom(buildSecretProtection()), { historyDisabled: true });
  assert.deepEqual(result.saved, []);
  assert.equal(result.selected, "Unrelated Tab");
  assert.match(JSON.stringify(result.notices), /SECRET_SAVE_FAILED/);
});
