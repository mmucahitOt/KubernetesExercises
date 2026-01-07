const express = require("express");
const app = express();
const port = process.env.PORT || 3000;
const version = process.env.VERSION || "v1";

const greeting = version === "v1" 
  ? "Hello from version 1" 
  : "Hello from version 2";

app.get("/", (req, res) => {
  res.send(greeting);
});

app.get("/healthz", (req, res) => {
  res.status(200).send("OK");
});

app.listen(port, () => {
  console.log(`Greeter ${version} listening on port ${port}`);
});

