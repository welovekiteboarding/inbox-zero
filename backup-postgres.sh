#!/bin/bash
# backup-postgres.sh - Backup the PostgreSQL database

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="./db_backups"
BACKUP_FILE="${BACKUP_DIR}/inboxdb_backup_${TIMESTAMP}.sql"

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

echo "📦 Creating database backup..."
docker exec inbox-zero-postgres-1 pg_dump -U inbox -d inboxdb > "${BACKUP_FILE}"

if [ $? -eq 0 ]; then
  echo "✅ Database backup created successfully: ${BACKUP_FILE}"
  echo "   Size: $(du -h "${BACKUP_FILE}" | cut -f1)"
else
  echo "❌ Database backup failed!"
fi
