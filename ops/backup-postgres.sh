#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?Set DATABASE_URL}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BACKUP_DIR/qayyum-$STAMP.dump"
pg_dump "$DATABASE_URL" --format=custom --no-owner --no-acl --file="$OUT"
chmod 600 "$OUT"
sha256sum "$OUT" > "$OUT.sha256"
echo "Backup created: $OUT"
echo "Store a second encrypted copy outside this server and test restoration regularly."
