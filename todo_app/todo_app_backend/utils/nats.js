const { connect, StringCodec } = require("nats");
const { logError, logInfo } = require("./logger");
const { natsUrl } = require("./config");

const sc = StringCodec();

let nc;

async function initNats() {
  const url = natsUrl;

  try {
    logInfo("Connecting to NATS", { url });
    nc = await connect({ servers: url });
    logInfo("Connected to NATS", { url });

    (async () => {
      for await (const status of nc.status()) {
        logInfo("NATS status", { type: status.type, data: status.data });
      }
    })().catch((err) => {
      logError("Error reading NATS status", err);
    });

    return nc;
  } catch (err) {
    logError("Failed to connect to NATS", err, { url });
    throw err;
  }
}

function getNats() {
  if (!nc) {
    throw new Error("NATS connection not initialized. Call initNats() first.");
  }
  return nc;
}

function publishEvent(subject, payload) {
  try {
    const client = getNats();
    const data = sc.encode(JSON.stringify(payload));
    client.publish(subject, data);
  } catch (err) {
    logError("Failed to publish NATS event", err, { subject, payload });
  }
}

const TODO_SUBJECTS = {
  todo_created: "todo.created",
  todo_updated: "todo.updated",
  todo_deleted: "todo.deleted",
};
module.exports = { initNats, publishEvent, TODO_SUBJECTS };
