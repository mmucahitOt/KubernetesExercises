const express = require("express");
const path = require("path");
const config = require("./utils/config");
const ImageRequestManager = require("./utils/image-request-manager");

const port = Number(config.port) || 3000;
const app = express();
const imageRequestManager = new ImageRequestManager();

app.use(express.static(path.join(__dirname, "public")));

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.get("/randomimage", (req, res) => {
  Promise.resolve(imageRequestManager.getImage())
    .then((image) => {
      // Prevent client/proxy caching so new image is fetched when ready
      res.setHeader(
        "Cache-Control",
        "no-store, no-cache, must-revalidate, proxy-revalidate"
      );
      res.setHeader("Pragma", "no-cache");
      res.setHeader("Expires", "0");
      res.setHeader("Surrogate-Control", "no-store");
      res.setHeader("Content-Type", "image/jpeg");
      res.send(image);
    })
    .catch((err) => {
      res.status(500).send("Failed to get image");
    });
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
