const { Todo } = require("../models/todo");

async function createTodo({ text }) {
  return await Todo.create({ text });
}

async function listTodos(params) {
  const filter = params?.filter ? params.filter : undefined;
  return await Todo.findAll({ order: [["createdAt", "DESC"]] });
}

async function getTodoById(id) {
  return await Todo.findByPk(id);
}

async function findAll() {
  return await Todo.findAll();
}

async function updateTodoById(id, updates) {
  const todo = await Todo.findByPk(id);
  if (!todo) {
    return null;
  }
  await todo.update(updates);
  return todo;
}

async function deleteTodoById(id) {
  return await Todo.destroy({ where: { id } });
}

module.exports = {
  createTodo,
  listTodos,
  getTodoById,
  updateTodoById,
  deleteTodoById,
  findAll,
};
