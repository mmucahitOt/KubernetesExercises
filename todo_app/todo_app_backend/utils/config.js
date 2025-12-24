require("dotenv").config();

module.exports = {
  port: Number(process.env.TODO_APP_BACKEND_PORT),
  randomImagePath: process.env.RANDOM_IMAGE_PATH,
  dbUrl: process.env.TODO_APP_BACKEND_DB_URL,
  natsUrl: process.env.NATS_URL || "nats://nats:4222",
};
