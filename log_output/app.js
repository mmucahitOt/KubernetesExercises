const { v4: uuidv4 } = require("uuid");

/**
 * Generates a random UUID string using the uuid package
 */
function generateUUID() {
  return uuidv4();
}

setInterval(() => {
  console.log(generateUUID());
}, 5000);
