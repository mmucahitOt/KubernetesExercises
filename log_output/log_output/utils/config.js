require("dotenv").config();

module.exports = {
  port: process.env.LOG_OUTPUT_PORT,
  logFilePath: process.env.LOG_FILE_PATH ?? "./logs/log.txt",
  requestCounterFilePath: process.env.REQUEST_COUNT_FILE_PATH ?? "./files/count.txt",
};
