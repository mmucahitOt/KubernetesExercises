const express = require("express");
const config = require("./config");

const port = config.port || 3000;
const app = express();

app.get("/", (req, res) => {
  res.send("Hello World");
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
