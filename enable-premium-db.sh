#!/bin/bash
# enable-premium-db.sh - Enable premium features via direct database modification

# Define colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔑 PREMIUM ACCESS ENABLEMENT TOOL 🔑${NC}"
echo "This script will enable premium features by directly modifying the database."
echo "It will create a Premium record with a far-future expiration date and link it to your user account."
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
echo -e "${YELLOW}Step 1: Identify the user account to upgrade${NC}"
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

# Check if user already has premium
echo "Checking current premium status..."
HAS_PREMIUM=$(docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -t -c "SELECT \"premiumId\" IS NOT NULL FROM \"User\" WHERE email = '$USER_EMAIL';" | tr -d ' ')

if [[ "$HAS_PREMIUM" == "t" ]]; then
  echo -e "${YELLOW}⚠️ User already has premium access${NC}"
  read -p "Would you like to update the existing premium subscription? (y/n): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
  fi
  echo "Proceeding with premium update..."
else
  echo -e "${GREEN}✅ User does not have premium access yet${NC}"
fi

# Create SQL commands to setup premium
echo -e "${YELLOW}Step 2: Creating premium subscription in database...${NC}"

SQL_COMMANDS=$(cat << EOSQL
-- Create Premium record with far-future renewal date and full access
WITH new_premium AS (
  INSERT INTO "Premium" (
    id, 
    "createdAt", 
    "updatedAt", 
    "lemonSqueezyRenewsAt", 
    "tier", 
    "bulkUnsubscribeAccess", 
    "aiAutomationAccess", 
    "coldEmailBlockerAccess", 
    "emailAccountsAccess"
  ) 
  VALUES (
    'prem_' || md5(random()::text), 
    NOW(), 
    NOW(), 
    NOW() + INTERVAL '10 year', 
    'LIFETIME', 
    'UNLOCKED', 
    'UNLOCKED', 
    'UNLOCKED', 
    999
  )
  RETURNING id
)
-- Update user to link to premium record
UPDATE "User" 
SET 
  "premiumId" = (SELECT id FROM new_premium),
  "premiumAdminId" = (SELECT id FROM new_premium)
WHERE 
  email = '$USER_EMAIL';

-- Verify the changes
SELECT 
  u.email, 
  u."premiumId", 
  p.tier, 
  p."lemonSqueezyRenewsAt", 
  p."bulkUnsubscribeAccess", 
  p."aiAutomationAccess", 
  p."coldEmailBlockerAccess",
  p."emailAccountsAccess"
FROM 
  "User" u
JOIN 
  "Premium" p ON u."premiumId" = p.id
WHERE 
  u.email = '$USER_EMAIL';
EOSQL
)

# Execute the SQL
echo "Executing database modifications..."
RESULT=$(echo "$SQL_COMMANDS" | docker exec -i inbox-zero-postgres-1 psql -U inbox -d inboxdb)

# Check if the operation was successful
if [ $? -eq 0 ]; then
  # Extract premium details from result
  PREMIUM_ID=$(echo "$RESULT" | grep "premiumId" | awk '{print $2}')
  TIER=$(echo "$RESULT" | grep "tier" | awk '{print $2}')
  EXPIRES=$(echo "$RESULT" | grep "lemonSqueezyRenewsAt" | awk '{print $2}')
  
  echo -e "${GREEN}✅ Premium features successfully enabled for $USER_EMAIL${NC}"
  echo ""
  echo -e "${BLUE}📋 PREMIUM SUBSCRIPTION DETAILS 📋${NC}"
  echo -e "User: ${GREEN}$USER_EMAIL${NC}"
  echo -e "Premium ID: ${GREEN}$PREMIUM_ID${NC}"
  echo -e "Tier: ${GREEN}$TIER${NC}"
  echo -e "Expires: ${GREEN}$EXPIRES${NC}"
  echo -e "Bulk Unsubscribe: ${GREEN}UNLOCKED${NC}"
  echo -e "AI Automation: ${GREEN}UNLOCKED${NC}"
  echo -e "Cold Email Blocker: ${GREEN}UNLOCKED${NC}"
  echo -e "Email Accounts: ${GREEN}999${NC}"
  echo ""
  echo "Premium subscription will be valid for 10 years!"
  echo ""
  echo "Note: If the application is currently running, you may need to refresh"
  echo "      your browser or sign out and sign back in to see the changes."
  
  # Record operation in a log file
  echo "$(date): Premium features enabled for $USER_EMAIL" >> db-operations.log
else
  echo -e "${RED}❌ Error: Failed to enable premium features.${NC}"
  echo "   Please check the error message above."
  exit 1
fi

echo ""
echo -e "${GREEN}✅ PREMIUM ENABLEMENT SUCCESSFUL${NC}"
echo "You can now proceed with the next step in Task 12:"
echo "Testing premium features."
