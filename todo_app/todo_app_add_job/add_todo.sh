#!/usr/bin/env bash
set -euo pipefail

NOTE_TEXT="${1:-}"

# Resolve DB URL from env var
if [[ -z "${TODO_APP_BACKEND_DB_URL:-}" ]]; then
  echo "TODO_APP_BACKEND_DB_URL env var is required"
  exit 1
fi

command -v psql >/dev/null 2>&1 || { echo "psql not found on PATH"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl not found on PATH"; exit 1; }

# Fetch a random Wikipedia article URL from Location header
RANDOM_URL=$(curl -sI https://en.wikipedia.org/wiki/Special:Random \
  | awk '/^[Ll]ocation:/ {print $2}' \
  | tr -d '\r')

if [[ -z "$RANDOM_URL" ]]; then
  echo "Failed to resolve random article URL"
  exit 1
fi

# Build todo text: optional note + URL
if [[ -n "$NOTE_TEXT" ]]; then
  TODO_TEXT="$NOTE_TEXT - $RANDOM_URL"
else
  TODO_TEXT="<a href=\"$RANDOM_URL\">$RANDOM_URL</a>"
fi

# Escape single quotes for SQL literal
TODO_ESCAPED=${TODO_TEXT//\'/\'\'}

SQL="INSERT INTO todos(text) VALUES ('$TODO_ESCAPED') RETURNING id, text, done, created_at;"

psql -X -q -v ON_ERROR_STOP=1 "$TODO_APP_BACKEND_DB_URL" -c "$SQL"