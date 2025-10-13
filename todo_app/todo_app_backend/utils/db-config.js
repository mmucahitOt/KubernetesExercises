const { Sequelize } = require("sequelize");
const config = require("./config");
const { logInfo, logError } = require("./logger");

const sequelize = config.dbUrl
  ? new Sequelize(config.dbUrl, { logging: false })
  : new Sequelize({ dialect: "sqlite", storage: ":memory:", logging: false });

async function initDb() {
  try {
    logInfo("Initializing database connection");
    await sequelize.authenticate();
    logInfo("Database connection authenticated successfully");

    await sequelize.sync();
    logInfo("Database synchronized successfully");
    console.log("DB connected and synced");
  } catch (err) {
    logError("Database initialization failed", err);
    process.exit(1);
  }
}

module.exports = { sequelize, initDb };
