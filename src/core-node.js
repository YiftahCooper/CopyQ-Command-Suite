"use strict";

// Compatibility facade for existing Node consumers. Implementations live in
// feature modules and can also be required directly without this aggregate.
const { moduleNames } = require("./bundle-core");
module.exports = Object.assign({}, ...moduleNames.map((name) => require("./core/" + name)));
