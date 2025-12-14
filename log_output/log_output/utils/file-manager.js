// file-manager.js
const fs = require("fs");
const path = require("path");

class FileManager {
  constructor() {
    this.streams = new Map();
    this.setupGracefulShutdown();
  }

  readFile(filename, callback) {
    fs.readFile(filename, callback);
  }

  readFileSync(filename, encoding = "utf8") {
    try {
      return fs.readFileSync(filename, encoding);
    } catch (error) {
      console.error(`Error reading file ${filename}:`, error.message);
      return null;
    }
  }

  readMessageFromConfigFile(filePath) {
    try {
      const content = this.readFileSync(filePath);
      if (!content) return null;

      // Read file content directly, trim whitespace and remove surrounding quotes if present
      let fileContent = content.trim();
      // Remove surrounding quotes if the entire content is quoted
      if (
        (fileContent.startsWith('"') && fileContent.endsWith('"')) ||
        (fileContent.startsWith("'") && fileContent.endsWith("'"))
      ) {
        fileContent = fileContent.slice(1, -1);
      }

      return fileContent || null;
    } catch (error) {
      console.error("Error reading message from config file:", error.message);
      return null;
    }
  }

  getStream(filename) {
    if (!this.streams.has(filename)) {
      const stream = fs.createWriteStream(filename, {
        flags: "a",
        encoding: "utf8",
      });

      stream.on("error", (err) => {
        console.error(`Error writing to ${filename}:`, err);
      });

      this.streams.set(filename, stream);
    }
    return this.streams.get(filename);
  }

  log(filename, message) {
    const timestamp = new Date().toISOString();
    const logEntry = `[${timestamp}] ${message}\n`;
    const stream = this.getStream(filename);
    stream.write(logEntry);
  }

  logRequest(method, path, status, responseTime) {
    const message = `${method} ${path} ${status} ${responseTime}ms`;
    this.log("requests.log", message);
  }

  logError(error, context = "") {
    const message = `ERROR: ${error.message} ${context}`;
    this.log("errors.log", message);
  }

  setupGracefulShutdown() {
    const shutdown = () => {
      console.log("Shutting down file manager...");
      this.close();
      process.exit(0);
    };

    process.on("SIGINT", shutdown);
    process.on("SIGTERM", shutdown);
    process.on("exit", () => this.close());
  }

  close() {
    console.log("Closing all log streams...");
    for (const [filename, stream] of this.streams) {
      stream.end();
      console.log(`Closed stream for ${filename}`);
    }
    this.streams.clear();
  }
}

module.exports = FileManager;
