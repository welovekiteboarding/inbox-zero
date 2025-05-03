#!/bin/bash
# verify-db-backup.sh - Verify database backup integrity and completeness

# Define colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 DATABASE BACKUP VERIFICATION TOOL 🔍${NC}"
echo "This script will verify the integrity and completeness of your database backup"
echo "by comparing it with the live database and checking for critical tables."
echo ""

# Find the most recent backup file
BACKUP_DIR="./db_backups"
LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.sql 2>/dev/null | head -n 1)

# Check if backup exists
if [ -z "$LATEST_BACKUP" ] || [ ! -f "$LATEST_BACKUP" ]; then
  echo -e "${RED}❌ No backup file found in $BACKUP_DIR${NC}"
  echo "Please run ./backup-postgres.sh first to create a backup."
  exit 1
fi

# Get backup file information
BACKUP_SIZE=$(du -h "$LATEST_BACKUP" | cut -f1)
# Use wc -c instead of du -b for better compatibility
BACKUP_BYTES=$(wc -c < "$LATEST_BACKUP")
# Use more portable date command
BACKUP_DATE=$(date -r "$LATEST_BACKUP" "+%Y-%m-%d %H:%M:%S")

echo -e "${YELLOW}Step 1: Basic backup file verification...${NC}"
echo "Backup file: $LATEST_BACKUP"
echo "Created on: $BACKUP_DATE"
echo "Size: $BACKUP_SIZE ($BACKUP_BYTES bytes)"

# Check backup file size
if [ $BACKUP_BYTES -lt 10000 ]; then  # Backup should be at least 10KB
  echo -e "${RED}❌ Backup file is suspiciously small (${BACKUP_SIZE})${NC}"
  echo "Backup may be incomplete or corrupted."
  exit 1
fi

echo -e "${GREEN}✅ Backup file exists and has reasonable size${NC}"
echo ""

# Check for critical tables in the backup
echo -e "${YELLOW}Step 2: Checking for critical tables in backup...${NC}"

CRITICAL_TABLES=("User" "Premium" "EmailMessage" "EmailAccount" "Category" "ThreadTracker" "CleanupThread")
MISSING_TABLES=()

for TABLE in "${CRITICAL_TABLES[@]}"; do
  if grep -q "CREATE TABLE public.\"$TABLE\"" "$LATEST_BACKUP"; then
    echo -e "Table \"$TABLE\": ${GREEN}Found in backup${NC}"
  else
    echo -e "Table \"$TABLE\": ${RED}NOT FOUND in backup${NC}"
    MISSING_TABLES+=("$TABLE")
  fi
done

if [ ${#MISSING_TABLES[@]} -gt 0 ]; then
  echo -e "${RED}❌ Critical tables missing from backup: ${MISSING_TABLES[*]}${NC}"
  echo "Backup may be incomplete or corrupted."
  exit 1
fi

echo -e "${GREEN}✅ All critical tables found in backup${NC}"
echo ""

# Create a temporary database for verification
echo -e "${YELLOW}Step 3: Creating temporary verification database...${NC}"

# Check if Docker is running
if ! docker ps | grep -q inbox-zero-postgres-1; then
  echo -e "${RED}❌ PostgreSQL container is not running${NC}"
  echo "Please start Docker containers with docker-compose up -d"
  exit 1
fi

# Create temporary database
echo "Creating temporary database 'backup_verify_temp'..."
docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -c "DROP DATABASE IF EXISTS backup_verify_temp;" 2>/dev/null
docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -c "CREATE DATABASE backup_verify_temp;" 2>/dev/null

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Failed to create temporary database${NC}"
  echo "Verification cannot continue."
  exit 1
fi

# Import backup into temporary database
echo "Importing backup into temporary database (this may take a moment)..."
cat "$LATEST_BACKUP" | docker exec -i inbox-zero-postgres-1 psql -U inbox -d backup_verify_temp >/dev/null 2>&1

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Failed to import backup into temporary database${NC}"
  echo "Backup may be corrupted or incompatible."
  docker exec inbox-zero-postgres-1 psql -U inbox -c "DROP DATABASE IF EXISTS backup_verify_temp;" 2>/dev/null
  exit 1
fi

echo -e "${GREEN}✅ Backup successfully imported into temporary database${NC}"
echo ""

# Compare table counts between live and backup databases
echo -e "${YELLOW}Step 4: Comparing table record counts between live and backup databases...${NC}"

# Check record counts for critical tables
TABLE_COMPARISON_FAILED=false

for TABLE in "${CRITICAL_TABLES[@]}"; do
  # Get record count from live database
  LIVE_COUNT=$(docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -t -c "SELECT COUNT(*) FROM \"$TABLE\";" | tr -d ' ')
  
  # Get record count from backup database
  BACKUP_COUNT=$(docker exec inbox-zero-postgres-1 psql -U inbox -d backup_verify_temp -t -c "SELECT COUNT(*) FROM \"$TABLE\";" | tr -d ' ')
  
  # Compare counts
  if [ "$LIVE_COUNT" = "$BACKUP_COUNT" ]; then
    echo -e "Table \"$TABLE\": ${GREEN}$BACKUP_COUNT records (matches live database)${NC}"
  else
    echo -e "Table \"$TABLE\": ${YELLOW}$BACKUP_COUNT records (live database has $LIVE_COUNT)${NC}"
    
    # Only fail if backup has zero records but live has some
    if [ "$BACKUP_COUNT" -eq "0" ] && [ "$LIVE_COUNT" -ne "0" ]; then
      echo -e "${RED}❌ Backup contains empty table \"$TABLE\" but live database has data!${NC}"
      TABLE_COMPARISON_FAILED=true
    fi
  fi
done

# Clean up temporary database
echo "Cleaning up temporary verification database..."
docker exec inbox-zero-postgres-1 psql -U inbox -c "DROP DATABASE IF EXISTS backup_verify_temp;" >/dev/null 2>&1

if [ "$TABLE_COMPARISON_FAILED" = true ]; then
  echo -e "${RED}❌ Table comparison failed! Critical tables are missing data.${NC}"
  echo "Backup may be incomplete or corrupted."
  exit 1
fi

echo -e "${GREEN}✅ Table record counts verified successfully${NC}"
echo ""

# Verify backup can be restored (optional simulation)
echo -e "${YELLOW}Step 5: Verifying backup can be restored (simulation only)...${NC}"
echo "Checking backup file format and structure..."

# Check for common SQL dump patterns that should be present
if grep -q "PostgreSQL database dump" "$LATEST_BACKUP" && \
   grep -q "SET statement_timeout" "$LATEST_BACKUP" && \
   grep -q "CREATE TABLE" "$LATEST_BACKUP" && \
   grep -q "COPY" "$LATEST_BACKUP"; then
  echo -e "${GREEN}✅ Backup file has correct PostgreSQL dump format${NC}"
else
  echo -e "${RED}❌ Backup file does not appear to be a valid PostgreSQL dump${NC}"
  echo "Backup may be corrupted or in wrong format."
  exit 1
fi

# Final verification summary
echo ""
echo -e "${BLUE}📋 BACKUP VERIFICATION SUMMARY 📋${NC}"
echo -e "Backup file: ${GREEN}$LATEST_BACKUP${NC}"
echo -e "Size: ${GREEN}$BACKUP_SIZE${NC}"
echo -e "Created on: ${GREEN}$BACKUP_DATE${NC}"
echo -e "Critical tables: ${GREEN}All present${NC}"
echo -e "Record counts: ${GREEN}Verified${NC}"
echo -e "Format check: ${GREEN}Valid PostgreSQL dump${NC}"
echo ""
echo -e "${GREEN}✅ BACKUP VERIFICATION SUCCESSFUL${NC}"
echo "The backup appears to be complete and valid."
echo ""
echo "You can now proceed with the next step in Task 12:"
echo "Direct database modification for premium access."

# Record verification in a log file
echo "$(date): Backup verification completed successfully for $LATEST_BACKUP" >> db-operations.log
