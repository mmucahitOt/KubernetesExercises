const express = require("express");
const config = require("./utils/config");
const { generateUUID } = require("./utils/id-generator");
const FileManager = require("./utils/file-manager");

const port = config.port || 3000;
const app = express();
const fileManager = new FileManager();

const RANDOM_STRING = generateUUID();

app.get("/logoutput", (req, response) => {
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
  const id = generateUUID();
  console.log(id);
  fileManager.log(config.logFilePath, id);
}, 5000);
