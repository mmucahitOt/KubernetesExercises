const express = require("express");
const config = require("./utils/config");
const { generateUUID } = require("./utils/id-generator");
const {
  requestCounterMiddleware,
} = require("./middlewares/request-counter.middleware");

const port = config.port || 3002;
const app = express();

app.use(requestCounterMiddleware);

app.get("/pingpong", (req, response) => {
  response.send(`pong ${req.count}`);
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});

setInterval(() => {
  console.log(generateUUID());
}, 5000);
