const { Model, DataTypes } = require("sequelize");
const { sequelize } = require("../utils/db-config");

class PingCount extends Model {}

PingCount.init(
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    count: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
  },
  {
    sequelize,
    tableName: "ping_count", // match init SQL
    underscored: true,
    timestamps: true,
    modelName: "PingCount",
  }
);

module.exports = { PingCount };
