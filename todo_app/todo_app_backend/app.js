const express = require("express");
const config = require("./utils/config");
const cors = require("cors");
const { initDb } = require("./utils/db-config");
const todoRouter = require("./routers/todo.router");
const { requestLogger, logInfo, logError } = require("./utils/logger");
const todoRepository = require("./repository/todo-repository");
const { initNats } = require("./utils/nats");

const port = Number(config.port) || 3003;
const healthCheckPort = 3541; // Static port for health checks

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

// Separate health check server on static port
const healthCheckApp = express();
healthCheckApp.get("/healthz", async (req, res) => {
  try {
    await todoRepository.findAll();
    res.status(200).send("OK");
  } catch (error) {
    res.status(500).send("Internal Server Error");
    console.error(error);
  }
});

initDb()
  .then(() => initNats())
  .then(() => {
    app.listen(port, () => {
      logInfo("Todo backend server started", { port });
      console.log(`Server is running on port ${port}`);
    });

    healthCheckApp.listen(healthCheckPort, () => {
      console.log(`Health check server is running on port ${healthCheckPort}`);
    });
  })
  .catch((error) => {
    logError("Failed to initialize database", error);
    process.exit(1);
  });
