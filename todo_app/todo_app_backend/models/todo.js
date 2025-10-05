const { Model, DataTypes } = require("sequelize");
const { sequelize } = require("../utils/db-config");

class Todo extends Model {}

Todo.init(
  {
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true,
    },
    text: {
      type: DataTypes.TEXT,
      allowNull: false,
      defaultValue: "",
    },
  },
  {
    sequelize,
    tableName: "todos",
    underscored: true,
    timestamps: true,
    modelName: "Todo",
  }
);

module.exports = { Todo };
