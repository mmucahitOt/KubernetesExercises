require("dotenv").config();

module.exports = {
  port: process.env.READ_OUTPUT_PORT,
  logFilePath: process.env.LOG_FILE_PATH ?? "./logs/log.txt",
};
