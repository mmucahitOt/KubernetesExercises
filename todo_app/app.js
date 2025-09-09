const express = require("express");
const path = require("path");
const config = require("./config");

const port = Number(config.port) || 3000;
const app = express();

app.use(express.static(path.join(__dirname, "public")));

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "todo.html"));
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
