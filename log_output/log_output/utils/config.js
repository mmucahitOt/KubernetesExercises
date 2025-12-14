require("dotenv").config();
const FileManager = require("./file-manager");

const fileManager = new FileManager();

function getMessageFromFile() {
  const informationFileName =
    process.env.INFORMATION_FILE_NAME || "information.txt";
  const informationFilePath = `/config/${informationFileName}`;
  console.log(`Reading file from: ${informationFilePath}`);
  const fileContent =
    fileManager.readMessageFromConfigFile(informationFilePath);
  console.log(`File content read: ${fileContent}`);
  return fileContent || "default message";
}

console.log("Environment variables:");
console.log("MESSAGE:", process.env.MESSAGE);
console.log("INFORMATION_FILE_NAME:", process.env.INFORMATION_FILE_NAME);
console.log("LOG_OUTPUT_PORT:", process.env.LOG_OUTPUT_PORT);

module.exports = {
  port: process.env.LOG_OUTPUT_PORT,
  pingPortServiceUrl: process.env.PING_PONG_URL,
  message: process.env.MESSAGE,
  getMessageFromFile,
};
