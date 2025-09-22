require("dotenv").config();

module.exports = {
  port: process.env.TODO_APP_PORT,
  randomImagePath: process.env.RANDOM_IMAGE_PATH,
};
