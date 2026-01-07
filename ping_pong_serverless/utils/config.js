require("dotenv").config();

module.exports = {
  port: process.env.PING_PONG_SERVERLESS_PORT,
  requestCounterFilePath:
    process.env.REQUEST_COUNT_FILE_PATH ?? "./files/count.txt",
  DB_URL: process.env.PING_PONG_SERVERLESS_DB_URL,
};
