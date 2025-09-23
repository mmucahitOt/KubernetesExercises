require("dotenv").config();

module.exports = {
  port: process.env.LOG_OUTPUT_PORT,
  logFilePath: process.env.LOG_FILE_PATH ?? "./logs/log.txt",

  pingPortServiceUrl: process.env.PING_PONG_URL,
};
