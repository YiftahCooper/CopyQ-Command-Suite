"use strict";
const core = Object.assign({}, require("./core/routing"), require("./core/code"));
module.exports = { isCode: core.isCode, routeContent: core.route, hasCopyQOwnedFormat: function (formats) { return core.route({ text: "", formats: formats, mimeOwner: "application/x-copyq-owner", mimeHidden: "application/x-copyq-hidden" }).action === "passthrough"; } };
