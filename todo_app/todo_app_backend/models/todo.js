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
      type: DataTypes.STRING(140),
      allowNull: false,
      defaultValue: "",
      validate: {
        len: {
          args: [1, 140],
          msg: "Todo text must be between 1 and 140 characters",
        },
      },
    },
    done: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
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
