"use strict";
const core = require("./core-node");
module.exports = { isCode: core.isCode, routeContent: core.route, hasCopyQOwnedFormat: function (formats) { return core.route({ text: "", formats: formats, mimeOwner: "application/x-copyq-owner", mimeHidden: "application/x-copyq-hidden" }).action === "passthrough"; } };
