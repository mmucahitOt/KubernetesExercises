const express = require("express");
const config = require("./config");
const { generateUUID } = require("./helper");

const port = config.port || 3000;
const app = express();

const RANDOM_STRING = generateUUID();

app.get("/", (req, response) => {
  const timestamp = new Date().toISOString();
  response.send(`
    timestamp: ${timestamp},
    random_string: ${RANDOM_STRING}
    `);
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});

setInterval(() => {
  console.log(generateUUID());
}, 5000);
