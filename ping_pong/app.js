const express = require("express");
const config = require("./utils/config");
const {
  requestCounterMiddleware,
} = require("./middlewares/request-counter.middleware");

const port = config.port || 3002;
const app = express();

app.use(requestCounterMiddleware);

app.get("/pingpong", (req, res) => {
  res.send(`pong ${req.count}`);
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
