const { Sequelize } = require("sequelize");
const config = require("./config");

const sequelize = config.dbUrl
  ? new Sequelize(config.dbUrl, { logging: false })
  : new Sequelize({ dialect: "sqlite", storage: ":memory:", logging: false });

async function initDb() {
  try {
    await sequelize.authenticate();
    await sequelize.sync();
    console.log("DB connected and synced");
  } catch (err) {
    console.error("DB connection error:", err);
    process.exit(1);
  }
}

module.exports = { sequelize, initDb };
