const { connect, StringCodec } = require("nats");
const { logInfo, logError } = require("./logger");
const { natsUrl, serviceName } = require("./config");

const sc = StringCodec();
let nc;

async function initNats() {
  try {
    logInfo("Connecting to NATS", { natsUrl, serviceName });
    nc = await connect({ servers: natsUrl, name: serviceName });
    logInfo("Connected to NATS", { natsUrl, serviceName });

    (async () => {
      for await (const status of nc.status()) {
        logInfo("NATS status", { type: status.type, data: status.data });
      }
    })().catch((err) => logError("Error reading NATS status", err));

    return nc;
  } catch (err) {
    logError("Failed to connect to NATS", err, { natsUrl, serviceName });
    throw err;
  }
}

function getNats() {
  if (!nc) {
    throw new Error("NATS connection not initialized. Call initNats() first.");
  }
  return nc;
}

const TODO_SUBJECTS = {
  todo_created: "todo.created",
  todo_updated: "todo.updated",
  todo_deleted: "todo.deleted",
};

const TODO_QUEUE_GROUP = "todo-broadcaster";

module.exports = { initNats, getNats, sc, TODO_SUBJECTS, TODO_QUEUE_GROUP };
