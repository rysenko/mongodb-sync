#!/bin/bash
set -euo pipefail

# Support old Docker "link" env vars + explicit vars
MONGODB_HOST="${MONGODB_RESTORE_PORT_27017_TCP_ADDR:-${MONGODB_RESTORE_PORT_1_27017_TCP_ADDR:-${MONGODB_RESTORE_HOST:-}}}"
MONGODB_PORT="${MONGODB_RESTORE_PORT_27017_TCP_PORT:-${MONGODB_RESTORE_PORT_1_27017_TCP_PORT:-${MONGODB_RESTORE_PORT:-27017}}}"

MONGODB_USER="${MONGODB_RESTORE_USER:-${MONGODB_RESTORE_ENV_MONGODB_USER:-}}"
MONGODB_PASS="${MONGODB_RESTORE_PASS:-${MONGODB_RESTORE_ENV_MONGODB_PASS:-}}"
MONGODB_DB="${MONGODB_RESTORE_DB:-}"

# If password is set but user isn't, default to admin (as in original script)
if [[ -z "${MONGODB_USER}" && -n "${MONGODB_PASS}" ]]; then
  MONGODB_USER="admin"
fi

# Optional auth DB (recommended). Can also be passed via EXTRA_RESTORE_OPTS.
MONGODB_AUTH_DB="${MONGODB_AUTH_DB:-${MONGODB_RESTORE_AUTH_DB:-}}"

# Build mongorestore args safely
args=(mongorestore
  "--host" "${MONGODB_HOST}"
  "--port" "${MONGODB_PORT}"
  "--drop"
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

# Determine archive to restore
ARCHIVE_TO_RESTORE="${1:-}"

if [[ -z "${ARCHIVE_TO_RESTORE}" ]]; then
  # No argument — download latest from S3
  : "${S3_BUCKET:?S3_BUCKET is required when no archive specified}"
  S3_PATH="${S3_PATH:-}"

  echo "=> Fetching latest archive from S3..."
  # Look for both .archive.gz (new) and .tgz (legacy), take the latest by name
  LATEST=$(aws s3 ls "s3://${S3_BUCKET}/${S3_PATH%/}/" 2>/dev/null | grep -E '\.(archive\.gz|tgz)$' | sort | tail -n 1 | awk '{print $4}' || true)

  if [[ -z "${LATEST}" ]]; then
    echo "=> No archives found in s3://${S3_BUCKET}/${S3_PATH%/}/" >&2
    exit 1
  fi

  echo "   Downloading ${LATEST}"
  aws s3 cp "s3://${S3_BUCKET}/${S3_PATH%/}/${LATEST}" "/backup/${LATEST}"
  ARCHIVE_TO_RESTORE="/backup/${LATEST}"
else
  # Argument provided — use local file
  if [[ "${ARCHIVE_TO_RESTORE}" != /* ]]; then
    ARCHIVE_TO_RESTORE="/backup/${ARCHIVE_TO_RESTORE}"
  fi
fi

# Handle legacy formats (.tgz or directory) — delegate to restore_legacy.sh
if [[ "${ARCHIVE_TO_RESTORE}" == *.tgz || -d "${ARCHIVE_TO_RESTORE}" ]]; then
  echo "=> Legacy format detected, delegating to restore_legacy.sh"
  exec /restore_legacy.sh "${ARCHIVE_TO_RESTORE}"
fi

if [[ ! -f "${ARCHIVE_TO_RESTORE}" ]]; then
  echo "=> Archive not found: ${ARCHIVE_TO_RESTORE}" >&2
  exit 1
fi

# Use archive mode with gzip
args+=("--archive=${ARCHIVE_TO_RESTORE}" "--gzip")

# Allow extra options
# Examples: EXTRA_RESTORE_OPTS="--nsInclude=mydb.*"
if [[ -n "${EXTRA_RESTORE_OPTS:-}" ]]; then
  # shellcheck disable=SC2206
  extra=( ${EXTRA_RESTORE_OPTS} )
  args+=("${extra[@]}")
fi

echo "=> Restore database from ${ARCHIVE_TO_RESTORE}"
if "${args[@]}"; then
  echo "   Restore succeeded"
else
  echo "   Restore failed" >&2
  exit 1
fi

echo "=> Done"
