const express = require("express");
const config = require("./utils/config");
const cors = require("cors");
const { initDb } = require("./utils/db-config");
const todoRouter = require("./routers/todo.router");

const port = Number(config.port) || 3003;
const app = express();

app.use(cors());
app.use(express.json());

// Routes
app.use("/todos", todoRouter);

initDb().then(() => {
  app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
  });
});
