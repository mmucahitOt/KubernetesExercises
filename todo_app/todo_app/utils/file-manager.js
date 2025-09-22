// file-manager.js
const fs = require("fs");

class FileManager {
  constructor() {}
  readFile(filename, callback) {
    fs.readFile(filename, callback);
  }

  writeFile(filename, data, callback) {
    fs.writeFile(filename, data, undefined, callback);
  }

  append(filename, data, callback) {
    fs.appendFile(filename, data, undefined, callback);
  }

  readJpeg(filename, callback) {
    fs.readFile(filename, (error, data) => {
      if (error) {
        callback(error, null);
      } else {
        callback(null, data);
      }
    });
  }

  writeJpeg(filename, data, callback) {
    if (data && typeof data.pipe === "function") {
      const writeStream = fs.createWriteStream(filename);
      data.pipe(writeStream);

      writeStream.on("finish", () => {
        callback(null, "JPEG file written successfully");
      });

      writeStream.on("error", (error) => {
        callback(error, null);
      });
    } else {
      fs.writeFile(filename, data, (error) => {
        if (error) {
          callback(error, null);
        } else {
          callback(null, "JPEG file written successfully");
        }
      });
    }
  }
}

module.exports = FileManager;
