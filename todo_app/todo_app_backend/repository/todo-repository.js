const { Todo } = require("../models/todo");

async function createTodo({ text }) {
  return await Todo.create({ text });
}

async function listTodos() {
  return await Todo.findAll({ order: [["createdAt", "DESC"]] });
}

async function getTodoById(id) {
  return await Todo.findByPk(id);
}

async function deleteTodoById(id) {
  return await Todo.destroy({ where: { id } });
}

module.exports = {
  createTodo,
  listTodos,
  getTodoById,
  deleteTodoById,
};
