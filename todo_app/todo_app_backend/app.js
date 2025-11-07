const express = require("express");
const config = require("./utils/config");
const cors = require("cors");
const { initDb } = require("./utils/db-config");
const todoRouter = require("./routers/todo.router");
const { requestLogger, logInfo, logError } = require("./utils/logger");

const port = Number(config.port) || 3003;
const app = express();

app.use(cors());
app.use(express.json());

// Add request logging middleware
app.use(requestLogger);

// Routes
app.get("/", (req, res) => {
  res.status(200).send("OK");
});

app.use("/todos", todoRouter);

initDb()
  .then(() => {
    app.listen(port, () => {
      logInfo("Todo backend server started", { port });
      console.log(`Server is running on port ${port}`);
    });
  })
  .catch((error) => {
    logError("Failed to initialize database", error);
    process.exit(1);
  });
