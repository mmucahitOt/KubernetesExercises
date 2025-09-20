const express = require("express");
const config = require("./utils/config");
const FileManager = require("./utils/file-manager");

const port = config.port || 3001;
const app = express();
const fileManager = new FileManager();

app.get("/readoutput", (req, res) => {
  fileManager.readFile(config.logFilePath, (error, data) => {
    console.log(error);
    console.log(data);
    res.send(data.toString());
  });
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
