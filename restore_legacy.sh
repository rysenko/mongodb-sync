#!/bin/bash
set -euo pipefail

# Restore from legacy backup format (directory or .tgz archive)
# For new .archive.gz format use restore.sh

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

# Optional auth DB
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

# Determine what to restore
INPUT="${1:-}"
TEMP_DIR=""

cleanup() {
  if [[ -n "${TEMP_DIR}" && -d "${TEMP_DIR}" ]]; then
    rm -rf "${TEMP_DIR}"
  fi
}
trap cleanup EXIT

if [[ -z "${INPUT}" ]]; then
  # Match original behavior exactly:
  # ls /backup -N1 | grep -iv ".tgz" | sort -r | head -n 1
  # Sort by NAME (reverse), not by date. Exclude .tgz and .archive.gz
  FILE_TO_RESTORE=$(ls -1 /backup 2>/dev/null | grep -iv "\.tgz$" | grep -iv "\.archive\.gz$" | sort -r | head -n 1 || true)
  if [[ -z "${FILE_TO_RESTORE}" ]]; then
    echo "=> No legacy backup found in /backup/" >&2
    exit 1
  fi
  INPUT="/backup/${FILE_TO_RESTORE}"
else
  # Argument provided — prepend /backup/ if relative (matches original behavior)
  if [[ "${INPUT}" != /* ]]; then
    INPUT="/backup/${INPUT}"
  fi
fi

# Handle .tgz archive
if [[ "${INPUT}" == *.tgz ]]; then
  if [[ ! -f "${INPUT}" ]]; then
    echo "=> Archive not found: ${INPUT}" >&2
    exit 1
  fi
  echo "=> Extracting ${INPUT}"
  TEMP_DIR=$(mktemp -d)
  tar xzf "${INPUT}" -C "${TEMP_DIR}" --strip-components=1
  RESTORE_PATH="${TEMP_DIR}"
elif [[ -d "${INPUT}" ]]; then
  RESTORE_PATH="${INPUT}"
else
  echo "=> Not a directory or .tgz file: ${INPUT}" >&2
  exit 1
fi

# Allow extra options
if [[ -n "${EXTRA_RESTORE_OPTS:-}" ]]; then
  # shellcheck disable=SC2206
  extra=( ${EXTRA_RESTORE_OPTS} )
  args+=("${extra[@]}")
fi

# Add the path to restore from
args+=("${RESTORE_PATH}")

echo "=> Restore database from ${INPUT}"
if "${args[@]}"; then
  echo "   Restore succeeded"
else
  echo "   Restore failed" >&2
  exit 1
fi

echo "=> Done"
