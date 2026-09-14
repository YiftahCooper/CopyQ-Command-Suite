"use strict";
const test = require('node:test');
const assert = require('node:assert/strict');
const setup = require('../scripts/setup/command-plan');
const router = { internalId:'canonical.dispatcher', name:'Clipboard Router', automatic:true, cmd:'safe' };
const secret = { internalId:'canonical.secret-protection', name:'Secret Protection', automatic:true, cmd:'safe' };
const undo = { internalId:'canonical.undo-delete', name:'Undo', shortcuts:['Ctrl+Z'], cmd:'undo' };
const known = [router.internalId, secret.internalId, undo.internalId, 'canonical.undoable-delete-listener','canonical.show-frequent'];
const serialize = x => JSON.stringify(x);

test('selection includes the undo pair and required router, rejecting incompatible protection', () => {
  assert.deepEqual(setup.expandSelection(['canonical.undo-delete'],known),['canonical.undo-delete','canonical.undoable-delete-listener']);
  assert.deepEqual(setup.expandSelection(['canonical.show-frequent'],known),['canonical.show-frequent','canonical.dispatcher']);
  assert.throws(()=>setup.expandSelection(['canonical.show-frequent',secret.internalId],known),/PROTECTION_CONFLICT/);
  assert.throws(()=>setup.expandSelection(['invented'],known),/UNKNOWN_COMMAND/);
});
test('planning preserves native objects and unrelated commands and is idempotent', () => {
  const custom = {name:'Custom',cmd:'other',re:/^foo$/};
  const before = [custom,{...router,cmd:'old'}];
  const plan = setup.plan(before,[router],serialize,{});
  assert.equal(plan.commands[0],router);
  assert.equal(plan.commands[1],custom);
  assert.equal(custom.re.test('foo'),true);
  assert.deepEqual(plan.updated,[router.internalId]);
  assert.deepEqual(setup.plan(plan.commands,[router],serialize,{}).unchanged,[router.internalId]);
  assert.equal(before[1].cmd,'old');
});
test('only the selected protection alternative replaces the incompatible handler', () => {
  const p = setup.plan([router,{name:'Mine',cmd:'mine'}],[secret],serialize,{});
  assert.deepEqual(p.replacedProtection,[router.internalId]);
  assert.deepEqual(p.commands.map(x=>x.name),['Secret Protection','Mine']);
});
test('deferring translation preserves its complete native object and Moonlander while updating the router', () => {
  const translation = {internalId:'canonical.translate-en', name:'Translate to English',
    cmd:'private installed helper', enable:true, re:/^KEEP$/, globalShortcuts:[]};
  const moonlander = {name:'Moonlander: Smart Title Case', cmd:'existing companion', globalShortcuts:['F13']};
  const disabled = {name:'Old URL handler', cmd:'existing vendor', enable:false};
  const before = [{...router,cmd:'old'}, translation, moonlander, disabled];
  const original = serialize(before);
  const p = setup.plan(before,[router],serialize,{});
  assert.deepEqual(p.updated,['canonical.dispatcher']);
  assert.equal(p.preserved,3);
  assert.deepEqual(p.commands.slice(1),[translation,moonlander,disabled]);
  assert.equal(p.commands[1],translation);
  assert.equal(p.commands[2],moonlander);
  assert.equal(p.commands[3],disabled);
  assert.equal(serialize(before),original);
});
test('duplicate identities, unowned names and shortcut collisions stop before mutation', () => {
  assert.throws(()=>setup.plan([router,router],[router],serialize,{}),/DUPLICATE_IDENTITY/);
  assert.throws(()=>setup.plan([{name:router.name,cmd:'user'}],[router],serialize,{}),/NAME_CONFLICT/);
  assert.throws(()=>setup.plan([{name:'Mine',shortcuts:['ctrl+z']}],[undo],serialize,{}),/SHORTCUT_CONFLICT/);
  const p = setup.plan([{name:'Mine',shortcuts:['ctrl+z']}],[undo],serialize,{'canonical.undo-delete':{local:['Ctrl+Shift+Z'],global:[]}});
  assert.deepEqual(p.commands[1].shortcuts,['Ctrl+Shift+Z']);
  assert.deepEqual(undo.shortcuts,['Ctrl+Z']);
});
