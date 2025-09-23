const express = require("express");
const config = require("./utils/config");
const {
  requestCounterMiddleware,
  requestCounter,
} = require("./middlewares/request-counter.middleware");

const port = config.port || 3002;
const app = express();

app.get("/pings", (req, res) => {
  res.send(`${requestCounter.getCount()}`);
});

app.get("/pingpong", requestCounterMiddleware, (req, res) => {
  res.send(`pong ${req.count}`);
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
