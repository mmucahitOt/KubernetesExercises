require("dotenv").config();

module.exports = {
  natsUrl: process.env.NATS_URL || "nats://nats:4222",
  discordWebhookUrl: process.env.DISCORD_WEBHOOK_URL,
  serviceName: process.env.BROADCASTER_NAME || "todo-broadcaster",
};
