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

app.get("/pings", async (req, res) => {
  res.send(`${await requestCounter.getCount()}`);
});

app.get("/pingpong", requestCounterMiddleware, (req, res) => {
  res.send(`pong ${req.count}`);
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
