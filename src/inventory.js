"use strict";

function duplicates(values) {
  const locations = new Map();
  values.forEach(({ value, index }) => {
    if (value == null || value === "") return;
    const normalized = String(value).toLowerCase();
    if (!locations.has(normalized)) locations.set(normalized, { value, indices: [] });
    locations.get(normalized).indices.push(index);
  });
  return Array.from(locations.values()).filter((entry) => entry.indices.length > 1);
}

function shortcutsFor(command) {
  const values = [];
  [command.globalShortcuts, command.shortcuts].forEach((shortcuts) => {
    if (Array.isArray(shortcuts)) values.push(...shortcuts);
    else if (shortcuts) values.push(shortcuts);
  });
  return values;
}

function findDuplicates(commands) {
  const names = [];
  const shortcuts = [];
  (commands || []).forEach((command, index) => {
    names.push({ value: command.name, index });
    shortcutsFor(command).forEach((value) => shortcuts.push({ value, index }));
  });
  return { duplicateNames: duplicates(names), duplicateShortcuts: duplicates(shortcuts) };
}

module.exports = { findDuplicates };
