"use strict";


function isTrashExpired(deletedAt, now, retentionMs) {
  var deleted = Date.parse(String(deletedAt || ''));
  return isFinite(deleted) && Number(now) - deleted >= Number(retentionMs);
}

module.exports = { isTrashExpired: isTrashExpired };

