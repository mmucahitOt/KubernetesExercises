const express = require("express");
const axios = require("axios");
const { logInfo, logError, logWarn } = require("./utils/logger");
const { discordWebhookUrl } = require("./utils/config");
const {
  initNats,
  sc,
  TODO_SUBJECTS,
  TODO_QUEUE_GROUP,
} = require("./utils/nats");

const healthCheckPort = 3541;
let nc;

function decodePayload(data) {
  try {
    const decoded = sc.decode(data);
    return JSON.parse(decoded);
  } catch (error) {
    logWarn("Failed to decode NATS payload; sending raw buffer", { error });
    return null;
  }
}

async function sendToDiscord(subject, payload) {
  if (!discordWebhookUrl) {
    logError("DISCORD_WEBHOOK_URL is not configured; skipping message");
    return;
  }

  const prettyPayload = payload
    ? "```json\n" + JSON.stringify(payload, null, 2) + "\n```"
    : "`<no payload>`";

  const content = [`**Todo event:** \`${subject}\``, prettyPayload].join("\n");

  try {
    await axios.post(discordWebhookUrl, { content });
    logInfo("Delivered event to Discord", { subject });
  } catch (error) {
    logError("Failed to deliver event to Discord", error, { subject });
  }
}

async function start() {
  if (!discordWebhookUrl) {
    logWarn("DISCORD_WEBHOOK_URL not configured; broadcaster will log messages only (no external forwarding)");
  }

  nc = await initNats();

  const subjects = Object.values(TODO_SUBJECTS);
  subjects.forEach((subject) => {
    const subscription = nc.subscribe(subject, { queue: TODO_QUEUE_GROUP });
    (async () => {
      for await (const msg of subscription) {
        const payload = decodePayload(msg.data);
        logInfo("Received todo event", { subject: msg.subject, payload });
        await sendToDiscord(msg.subject, payload);
      }
    })().catch((error) => logError("Subscription error", error, { subject }));
  });

  const healthApp = express();
  healthApp.get("/healthz", (_req, res) => {
    if (!nc || nc.isClosed()) {
      return res.status(503).send("NATS not connected");
    }
    return res.status(200).send("OK");
  });

  healthApp.listen(healthCheckPort, () => {
    logInfo("Health check server started", { port: healthCheckPort });
  });

  const shutdown = async () => {
    logInfo("Shutting down broadcaster");
    await nc.drain();
    process.exit(0);
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

start().catch((error) => {
  logError("Broadcaster failed to start", error);
  process.exit(1);
});
