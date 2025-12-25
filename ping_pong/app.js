// GitOps automated deployment - changes trigger build and validation workflows
const express = require("express");
const config = require("./utils/config");
const {
  requestCounterMiddleware,
  requestCounter,
} = require("./middlewares/request-counter.middleware");
const { connectToDb } = require("./utils/db-config");

connectToDb();

const port = config.port || 3002;
const app = express();

app.get("/", (req, res) => {
  res.status(200).send("OK");
});

app.get("/healthz", async (req, res) => {
  try {
    await requestCounter.findAll();
    res.status(200).send("OK");
  } catch (error) {
    res.status(500).send("Internal Server Error");
    console.error(error);
  }
});

app.get("/pings", async (req, res) => {
  res.send(`${await requestCounter.getCount()}`);
});

app.get("/pingpong", requestCounterMiddleware, (req, res) => {
  res.send(`pong ${req.count}`);
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
