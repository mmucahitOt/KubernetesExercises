const repo = require("../repository/todo-repository");

async function create(req, res) {
  const { text } = req.body || {};
  if (!text || typeof text !== "string") {
    return res.status(400).json({ error: "Field 'text' is required" });
  }
  const todo = await repo.createTodo({ text });
  return res.status(201).json(todo);
}

async function list(_req, res) {
  const todos = await repo.listTodos();
  return res.json(todos);
}

async function getById(req, res) {
  const todo = await repo.getTodoById(req.params.id);
  if (!todo) return res.status(404).json({ error: "Not found" });
  return res.json(todo);
}

async function remove(req, res) {
  const deleted = await repo.deleteTodoById(req.params.id);
  if (!deleted) return res.status(404).json({ error: "Not found" });
  return res.status(204).send();
}

module.exports = { create, list, getById, remove };