// file-manager.js
const fs = require("fs");

class FileManager {
  constructor() {
  }
  readFile(filename, callback) {
    fs.readFile(filename, callback)
  }
}

module.exports = FileManager;
