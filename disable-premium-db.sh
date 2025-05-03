#!/bin/bash
# disable-premium-db.sh - Disable premium features by removing database records

# Define colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔒 PREMIUM ACCESS REMOVAL TOOL 🔒${NC}"
echo "This script will disable premium features by removing the premium record"
echo "from your user account in the database."
echo ""

# Check if backup exists
BACKUP_DIR="./db_backups"
LATEST_BACKUP=$(ls -t $BACKUP_DIR/*.sql 2>/dev/null | head -n 1)

if [ -z "$LATEST_BACKUP" ] || [ ! -f "$LATEST_BACKUP" ]; then
  echo -e "${YELLOW}⚠️ No database backup found${NC}"
  echo "It's strongly recommended to create a backup before proceeding."
  read -p "Would you like to create a backup now? (y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creating backup..."
    ./backup-postgres.sh
    if [ $? -ne 0 ]; then
      echo -e "${RED}❌ Backup failed. Aborting for safety.${NC}"
      exit 1
    fi
  else
    echo -e "${YELLOW}⚠️ Proceeding without backup. This is not recommended.${NC}"
    read -p "Are you sure you want to continue without a backup? (type 'yes' to confirm): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
      echo "Operation cancelled."
      exit 0
    fi
  fi
fi

# Check if Docker is running
if ! docker ps | grep -q inbox-zero-postgres-1; then
  echo -e "${RED}❌ PostgreSQL container is not running${NC}"
  echo "Please start Docker containers with docker-compose up -d"
  exit 1
fi

# Get user email
USER_EMAIL=""
echo -e "${YELLOW}Step 1: Identify the user account to downgrade${NC}"
read -p "Enter your Inbox Zero account email: " USER_EMAIL

if [[ -z "$USER_EMAIL" ]]; then
  echo -e "${RED}❌ No email provided. Aborting.${NC}"
  exit 1
fi

# Check if the user exists
echo "Checking if user exists..."
USER_EXISTS=$(docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -t -c "SELECT COUNT(*) FROM \"User\" WHERE email = '$USER_EMAIL';" | tr -d ' ')

if [[ "$USER_EXISTS" -eq 0 ]]; then
  echo -e "${RED}❌ Error: User with email $USER_EMAIL not found in database.${NC}"
  echo "   Please make sure you've signed up and the email is correct."
  exit 1
fi

echo -e "${GREEN}✅ User found in database${NC}"

# Check if user has premium
echo "Checking current premium status..."
PREMIUM_INFO=$(docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -t -c "
  SELECT 
    u.\"premiumId\",
    p.id
  FROM \"User\" u
  LEFT JOIN \"Premium\" p ON u.\"premiumId\" = p.id
  WHERE u.email = '$USER_EMAIL';
")

PREMIUM_ID=$(echo "$PREMIUM_INFO" | head -n 1 | awk '{print $1}' | tr -d ' ')

if [[ -z "$PREMIUM_ID" || "$PREMIUM_ID" == "|" ]]; then
  echo -e "${YELLOW}⚠️ User does not have premium access${NC}"
  echo "No premium subscription to remove."
  exit 0
fi

echo -e "${GREEN}✅ Premium subscription found${NC}"

# Confirm removal
echo -e "${YELLOW}⚠️ Warning: This will remove premium access from your account${NC}"
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Operation cancelled."
  exit 0
fi

# Create SQL commands to remove premium
echo -e "${YELLOW}Step 2: Removing premium subscription from database...${NC}"

SQL_COMMANDS=$(cat << EOSQL
-- Get the current premiumId
WITH user_premium AS (
  SELECT "premiumId" FROM "User" WHERE email = '$USER_EMAIL'
),
-- Delete Premium record but only if this is the only user using it
deleted_premium AS (
  DELETE FROM "Premium" 
  WHERE id IN (
    SELECT "premiumId" FROM user_premium
  )
  AND (
    SELECT COUNT(*) FROM "User" WHERE "premiumId" IN (SELECT "premiumId" FROM user_premium)
  ) = 1
  RETURNING id
)
-- Remove premium references from user
UPDATE "User"
SET 
  "premiumId" = NULL,
  "premiumAdminId" = NULL
WHERE 
  email = '$USER_EMAIL';

-- Verify the changes
SELECT 
  email, 
  "premiumId"
FROM 
  "User"
WHERE 
  email = '$USER_EMAIL';
EOSQL
)

# Execute the SQL
echo "Executing database modifications..."
RESULT=$(echo "$SQL_COMMANDS" | docker exec -i inbox-zero-postgres-1 psql -U inbox -d inboxdb)

# Check if the operation was successful
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Premium features successfully disabled for $USER_EMAIL${NC}"
  echo ""
  echo "Note: If the application is currently running, you may need to refresh"
  echo "      your browser or sign out and sign back in to see the changes."
  
  # Record operation in a log file
  echo "$(date): Premium features disabled for $USER_EMAIL" >> db-operations.log
else
  echo -e "${RED}❌ Error: Failed to disable premium features.${NC}"
  echo "   Please check the error message above."
  exit 1
fi

echo ""
echo -e "${GREEN}✅ PREMIUM REMOVAL SUCCESSFUL${NC}"
echo "Your account has been returned to the free tier."
echo ""
echo "To re-enable premium features in the future, run:"
echo "./enable-premium-db.sh"
