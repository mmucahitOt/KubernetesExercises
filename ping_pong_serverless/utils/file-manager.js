// file-manager.js
const fs = require("fs");

class FileManager {
  constructor() {
  }
  readFile(filename, callback) {
    fs.readFile(filename, callback)
  }

  writeFile(filename, data, callback) {
    fs.writeFile(filename, data, undefined, callback)
  }
  append(filename, data, callback) {
    fs.appendFile(filename, data, undefined, callback)
  }
}

module.exports = FileManager;
