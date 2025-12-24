# Todo App Broadcaster

Listens to todo events on NATS (`todo.created`, `todo.updated`, `todo.deleted`)
and forwards them to a Discord channel via webhook.

## Run locally

1. Set env vars:
   - `DISCORD_WEBHOOK_URL` (required)
   - `NATS_URL` (optional, defaults `nats://nats:4222`)
   - `BROADCASTER_NAME` (optional client name)
2. Install deps: `npm install`
3. Start: `npm start`

## Docker

Build and run from this folder:

```
docker build -t todo-broadcaster .
docker run --rm \
  -e DISCORD_WEBHOOK_URL=... \
  -e NATS_URL=nats://nats:4222 \
  todo-broadcaster
```
