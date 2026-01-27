#!/bin/bash
set -euo pipefail

# Support old Docker "link" env vars + explicit vars
MONGODB_HOST="${MONGODB_BACKUP_PORT_27017_TCP_ADDR:-${MONGODB_BACKUP_PORT_1_27017_TCP_ADDR:-${MONGODB_BACKUP_HOST:-}}}"
MONGODB_PORT="${MONGODB_BACKUP_PORT_27017_TCP_PORT:-${MONGODB_BACKUP_PORT_1_27017_TCP_PORT:-${MONGODB_BACKUP_PORT:-27017}}}"

MONGODB_USER="${MONGODB_BACKUP_USER:-${MONGODB_BACKUP_ENV_MONGODB_USER:-}}"
MONGODB_PASS="${MONGODB_BACKUP_PASS:-${MONGODB_BACKUP_ENV_MONGODB_PASS:-}}"
MONGODB_DB="${MONGODB_BACKUP_DB:-}"

# If password is set but user isn't, default to admin (as in original script)
if [[ -z "${MONGODB_USER}" && -n "${MONGODB_PASS}" ]]; then
  MONGODB_USER="admin"
fi

# Optional auth DB (recommended). Can also be passed via EXTRA_BACKUP_OPTS.
MONGODB_AUTH_DB="${MONGODB_AUTH_DB:-${MONGODB_BACKUP_AUTH_DB:-}}"

# Build mongodump args safely
args=(mongodump
  "--host" "${MONGODB_HOST}"
  "--port" "${MONGODB_PORT}"
)

if [[ -n "${MONGODB_USER}" ]]; then
  args+=("--username" "${MONGODB_USER}")
fi
if [[ -n "${MONGODB_PASS}" ]]; then
  args+=("--password" "${MONGODB_PASS}")
fi
if [[ -n "${MONGODB_AUTH_DB}" ]]; then
  args+=("--authenticationDatabase" "${MONGODB_AUTH_DB}")
fi
if [[ -n "${MONGODB_DB}" ]]; then
  args+=("--db" "${MONGODB_DB}")
fi

BACKUP_NAME="$(date +%Y.%m.%d.%H%M%S)"
ARCHIVE_PATH="/backup/${BACKUP_NAME}.archive.gz"

# Create single-file archive suitable for streaming restore
args+=("--archive=${ARCHIVE_PATH}" "--gzip")

# Allow extra options (kept compatible with your previous approach: string gets word-split)
# Examples: EXTRA_BACKUP_OPTS="--readPreference=secondaryPreferred --oplog"
if [[ -n "${EXTRA_BACKUP_OPTS:-}" ]]; then
  # shellcheck disable=SC2206
  extra=( ${EXTRA_BACKUP_OPTS} )
  args+=("${extra[@]}")
fi

echo "=> Backup started"
if "${args[@]}"; then
  echo "   Backup succeeded: ${ARCHIVE_PATH}"

  if [[ -n "${S3_BACKUP:-}" ]]; then
    echo "   Copying archive to S3"
    : "${S3_BUCKET:?S3_BUCKET is required when S3_BACKUP is set}"
    S3_PATH="${S3_PATH:-}"

    aws s3 cp "${ARCHIVE_PATH}" "s3://${S3_BUCKET}/${S3_PATH%/}/${BACKUP_NAME}.archive.gz"

    echo "   S3 upload succeeded, removing local archive"
    rm -f "${ARCHIVE_PATH}"
  else
    echo "   S3_BACKUP not set; leaving local archive at ${ARCHIVE_PATH}"
  fi
else
  echo "   Backup failed" >&2
  # Keep any partial file for debugging? remove to match old behavior
  rm -f "${ARCHIVE_PATH}" || true
  exit 1
fi

echo "=> Backup done"