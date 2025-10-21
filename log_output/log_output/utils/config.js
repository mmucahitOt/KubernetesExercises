require("dotenv").config();
const FileManager = require("./file-manager");

const fileManager = new FileManager();

function getMessageFromFile() {
  const informationFileName =
    process.env.INFORMATION_FILE_NAME || "information.txt";
  const informationFilePath = `/config/${informationFileName}`;
  const fileContent =
    fileManager.readMessageFromConfigFile(informationFilePath);
  return fileContent || "default message";
}

module.exports = {
  port: process.env.LOG_OUTPUT_PORT,
  pingPortServiceUrl: process.env.PING_PONG_URL,
  message: process.env.message,
  getMessageFromFile,
};
