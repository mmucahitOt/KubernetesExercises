#!/usr/bin/env bash
set -euo pipefail

# Resolve DB URL from env var
if [[ -z "${TODO_APP_BACKEND_DB_URL:-}" ]]; then
  echo "ERROR: TODO_APP_BACKEND_DB_URL env var is required"
  exit 1
fi

# GCS bucket from env var
if [[ -z "${GCS_BUCKET:-}" ]]; then
  echo "ERROR: GCS_BUCKET env var is required"
  exit 1
fi

# Check required commands
command -v pg_dump >/dev/null 2>&1 || { echo "ERROR: pg_dump not found on PATH"; exit 1; }
command -v gsutil >/dev/null 2>&1 || { echo "ERROR: gsutil not found on PATH"; exit 1; }

# Generate backup filename with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILENAME="todo_db_backup_${TIMESTAMP}.sql"
BACKUP_PATH="/tmp/${BACKUP_FILENAME}"

echo "Starting database backup..."
echo "Database: ${TODO_APP_BACKEND_DB_URL}"
echo "Backup file: ${BACKUP_FILENAME}"

# Create backup using pg_dump
pg_dump -Fc -v "$TODO_APP_BACKEND_DB_URL" -f "$BACKUP_PATH" || {
  echo "ERROR: pg_dump failed"
  exit 1
}

echo "Backup created successfully: ${BACKUP_PATH}"
echo "File size: $(du -h "$BACKUP_PATH" | cut -f1)"

# Upload to Google Cloud Storage
echo "Uploading backup to GCS bucket: ${GCS_BUCKET}"

# Debug: Check environment and tools
echo "DEBUG: GOOGLE_APPLICATION_CREDENTIALS=${GOOGLE_APPLICATION_CREDENTIALS:-not set}"
echo "DEBUG: Checking if gcloud is available..."
command -v gcloud >/dev/null 2>&1 && echo "DEBUG: gcloud found at $(which gcloud)" || echo "DEBUG: gcloud NOT found"
command -v gsutil >/dev/null 2>&1 && echo "DEBUG: gsutil found at $(which gsutil)" || echo "DEBUG: gsutil NOT found"

# Verify credentials file exists and authenticate
if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]] && [[ -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
  echo "Using service account credentials from: ${GOOGLE_APPLICATION_CREDENTIALS}"
  # Activate service account for gcloud/gsutil
  if command -v gcloud >/dev/null 2>&1; then
    gcloud auth activate-service-account --key-file="${GOOGLE_APPLICATION_CREDENTIALS}" --quiet || {
      echo "ERROR: Failed to activate service account"
      exit 1
    }
  else
    echo "ERROR: gcloud command not found. Cannot authenticate."
    exit 1
  fi
else
  echo "ERROR: GOOGLE_APPLICATION_CREDENTIALS not set or file not found at ${GOOGLE_APPLICATION_CREDENTIALS:-<not set>}"
  exit 1
fi

gsutil -m cp "$BACKUP_PATH" "gs://${GCS_BUCKET}/${BACKUP_FILENAME}" || {
  echo "ERROR: Failed to upload backup to GCS"
  exit 1
}

echo "Backup uploaded successfully to gs://${GCS_BUCKET}/${BACKUP_FILENAME}"

# Clean up local backup file
rm -f "$BACKUP_PATH"
echo "Local backup file removed"

echo "Backup completed successfully!"