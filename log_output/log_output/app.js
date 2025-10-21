const express = require("express");
const config = require("./utils/config");
const { generateUUID } = require("./utils/id-generator");
const { pingPong } = require("./services/ping-pong.service");

const port = config.port || 3000;
const app = express();

const RANDOM_STRING = generateUUID();

app.get("/", (req, res) => {
  res.status(200).send("OK");
});

app.get("/logoutput", async (req, res) => {
  const timestamp = new Date().toISOString();
  const count = await pingPong();
  res.send(`
      file content: ${config.getMessageFromFile()}
      env variable: MESSAGE=${config.message}
      ${timestamp}: ${RANDOM_STRING}
      Ping / Pong: ${count}
      `);
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});

setInterval(() => {
  const id = generateUUID();
  console.log(id);
}, 5000);
