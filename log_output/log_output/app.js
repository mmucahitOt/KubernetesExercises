// GitOps automated deployment - changes trigger build and validation workflows
const express = require("express");
const config = require("./utils/config");
const { generateUUID } = require("./utils/id-generator");
const { pingPong } = require("./services/ping-pong.service");
const { getGreeting } = require("./services/greeter.service");

const port = config.port || 3000;
const app = express();

const RANDOM_STRING = generateUUID();

app.get("/", (req, res) => {
  res.status(200).send("OK");
});

app.get("/healthz", async (req, res) => {
  try {
    await pingPong();
    res.status(200).send("OK");
  } catch (error) {
    res.status(500).send("Internal Server Error");
    console.error(error);
  }
});

app.get("/logoutput", async (req, res) => {
  const timestamp = new Date().toISOString();
  const count = await pingPong();
  const greeting = await getGreeting();
  res.send(`
      file content: ${config.getMessageFromFile()} \n
      env variable: MESSAGE=${config.message} \n
      ${timestamp}: ${RANDOM_STRING} \n
      Ping / Pong: ${count} \n
      greetings: ${greeting}
      `);
});

app.get("/status", async (req, res) => {
  const timestamp = new Date().toISOString();
  const count = await pingPong();
  const greeting = await getGreeting();
  res.send(`
    ${timestamp}: ${RANDOM_STRING}
    Ping / Pongs: ${count}
    env-variable: MESSAGE=${config.message}
    file contents: ${config.getMessageFromFile()}
    greetings: ${greeting}
  `);
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});

setInterval(() => {
  const id = generateUUID();
  console.log(id);
}, 5000);
