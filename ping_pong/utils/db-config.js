const { Sequelize } = require("sequelize");
const config = require("./config");

const sequelize = new Sequelize(config.DB_URL);

const connectToDb = async () => {
  try {
    await sequelize.authenticate();
    console.log("Connection has been established successfully.");
  } catch (error) {
    console.error("Unable to connect to the database:", error);
  }
};

process.on("SIGINT", async () => {
  try {
    await sequelize.close();
  } finally {
    process.exit(0);
  }
});

process.on("SIGTERM", async () => {
  try {
    await sequelize.close();
  } finally {
    process.exit(0);
  }
});

module.exports = {
  connectToDb,
  sequelize,
};
