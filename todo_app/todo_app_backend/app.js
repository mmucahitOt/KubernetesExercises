const express = require("express");
const config = require("./utils/config");
const { v4: uuidv4 } = require("uuid");
const cors = require("cors");

const port = Number(config.port) || 3003;
const app = express();

app.use(cors());
app.use(express.json());

const todosById = ["Learn JavaScript", "Learn React", "Build a project"].map(
  (text) => {
    return {
      id: uuidv4(),
      text: text,
      createdAt: new Date().toISOString(),
    };
  }
);

app.post("/todos", (req, res) => {
  const { text } = req.body || {};
  if (!text || typeof text !== "string") {
    return res.status(400).json({ error: "Field 'text' is required" });
  }

  const id = uuidv4();
  const todo = { id, text, createdAt: new Date().toISOString() };
  todosById[id] = todo;
  return res.status(201).json(todo);
});

app.get("/todos", (req, res) => {
  const todos = Object.values(todosById);
  return res.json(todos);
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
