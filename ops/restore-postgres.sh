#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?Set DATABASE_URL}"
FILE="${1:?Usage: restore-postgres.sh path/to/backup.dump}"
[[ -f "$FILE" ]] || { echo "Backup not found: $FILE" >&2; exit 1; }
echo "WARNING: this overwrites objects in the target database."
read -r -p "Type RESTORE to continue: " CONFIRM
[[ "$CONFIRM" == "RESTORE" ]] || { echo "Cancelled."; exit 1; }
pg_restore --clean --if-exists --no-owner --no-acl --dbname="$DATABASE_URL" "$FILE"
echo "Restore command completed. Run application smoke tests before reopening traffic."
