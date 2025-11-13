const express = require("express");
const path = require("path");
const config = require("./utils/config");
const ImageRequestManager = require("./utils/image-request-manager");

const port = Number(config.port) || 3000;
const healthCheckPort = 3541; // Static port for health checks

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

// Main app server
app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});

// Separate health check server on static port
const healthCheckApp = express();
healthCheckApp.get("/healthz", (req, res) => {
  res.status(200).send("OK");
});

healthCheckApp.listen(healthCheckPort, () => {
  console.log(`Health check server is running on port ${healthCheckPort}`);
});
