const repo = require("../repository/todo-repository");
const { logError, logInfo, logWarn } = require("../utils/logger");
const { publishEvent, TODO_SUBJECTS } = require("../utils/nats");

async function create(req, res) {
  try {
    const { text } = req.body || {};

    logInfo("Creating new todo", {
      textLength: text ? text.length : 0,
      hasText: !!text,
    });

    if (!text || typeof text !== "string") {
      logWarn("Todo creation failed: missing or invalid text field", {
        textType: typeof text,
        hasText: !!text,
      });
      return res.status(400).json({ error: "Field 'text' is required" });
    }

    const todo = await repo.createTodo({ text });

    logInfo("Todo created successfully", {
      todoId: todo.id,
      textLength: text ? text.length : 0,
      text: text,
    });

    publishEvent(TODO_SUBJECTS.todo_created, {
      title: "Todo created",
      message: `Todo "${todo.text}" was created with id ${todo.id}.`,
      todoId: todo.id,
      text: todo.text,
      createdAt: todo.createdAt,
    });

    return res.status(201).json(todo);
  } catch (error) {
    if (error.name === "SequelizeValidationError") {
      const validationErrors = error.errors.map((err) => ({
        field: err.path,
        message: err.message,
        type: err.type,
        validator: err.validatorName,
      }));

      logError("Todo creation failed: validation error", error, {
        textLength: req.body?.text?.length || 0,
        textPreview: req.body?.text
          ? req.body.text.substring(0, 50) +
            (req.body.text.length > 50 ? "..." : "")
          : null,
        validationErrors: validationErrors,
      });
      return res.status(400).json({
        error: error.errors[0].message,
      });
    }
    logError("Todo creation failed: unexpected error", error, {
      textLength: req.body?.text?.length || 0,
      textPreview: req.body?.text
        ? req.body.text.substring(0, 50) +
          (req.body.text.length > 50 ? "..." : "")
        : null,
    });
    return res.status(500).json({ error: "Internal server error" });
  }
}

async function list(req, res) {
  try {
    logInfo("Fetching todo list");
    const todos = await repo.listTodos();
    logInfo("Todo list fetched successfully", { count: todos.length });
    return res.json(todos);
  } catch (error) {
    logError("Failed to fetch todo list", error);
    return res.status(500).json({ error: "Internal server error" });
  }
}

async function getById(req, res) {
  try {
    const { id } = req.params;
    logInfo("Fetching todo by ID", { todoId: id });

    const todo = await repo.getTodoById(id);
    if (!todo) {
      logWarn("Todo not found", { todoId: id });
      return res.status(404).json({ error: "Not found" });
    }

    logInfo("Todo fetched successfully", { todoId: id });
    return res.json(todo);
  } catch (error) {
    logError("Failed to fetch todo by ID", error, { todoId: req.params.id });
    return res.status(500).json({ error: "Internal server error" });
  }
}

async function update(req, res) {
  try {
    const { id } = req.params;
    const { done } = req.body || {};

    logInfo("Updating todo", { todoId: id, done });

    if (typeof done !== "boolean") {
      logWarn("Todo update failed: invalid done field", {
        todoId: id,
        doneType: typeof done,
      });
      return res.status(400).json({ error: "Field 'done' must be a boolean" });
    }

    const todo = await repo.updateTodoById(id, { done });
    if (!todo) {
      logWarn("Todo not found for update", { todoId: id });
      return res.status(404).json({ error: "Not found" });
    }

    logInfo("Todo updated successfully", { todoId: id, done });

    publishEvent(TODO_SUBJECTS.todo_updated, {
      title: "Todo updated",
      message: `Todo "${todo.text}" (id ${todo.id}) was marked as ${
        todo.done ? "done" : "not done"
      }.`,
      todoId: todo.id,
      done: todo.done,
      updatedAt: todo.updatedAt,
    });

    return res.json(todo);
  } catch (error) {
    logError("Failed to update todo", error, { todoId: req.params.id });
    return res.status(500).json({ error: "Internal server error" });
  }
}

async function remove(req, res) {
  try {
    const { id } = req.params;
    logInfo("Deleting todo", { todoId: id });

    const deleted = await repo.deleteTodoById(id);
    if (!deleted) {
      logWarn("Todo not found for deletion", { todoId: id });
      return res.status(404).json({ error: "Not found" });
    }

    logInfo("Todo deleted successfully", { todoId: id });

    publishEvent(TODO_SUBJECTS.todo_deleted, {
      title: "Todo deleted",
      message: `Todo with id ${id} was deleted.`,
      todoId: id,
      deletedAt: new Date().toISOString(),
    });

    return res.status(204).send();
  } catch (error) {
    logError("Failed to delete todo", error, { todoId: req.params.id });
    return res.status(500).json({ error: "Internal server error" });
  }
}

module.exports = { create, list, getById, update, remove };
