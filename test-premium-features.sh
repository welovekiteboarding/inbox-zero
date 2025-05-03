#!/bin/bash
# test-premium-features.sh - Test premium features after enabling them

# Define colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 PREMIUM FEATURES TEST TOOL 🧪${NC}"
echo "This script will help you test and verify premium features are working correctly."
echo ""

# Check if Docker is running
if ! docker ps | grep -q inbox-zero-postgres-1; then
  echo -e "${RED}❌ PostgreSQL container is not running${NC}"
  echo "Please start Docker containers with docker-compose up -d"
  exit 1
fi

# Get user email
USER_EMAIL=""
echo -e "${YELLOW}Step 1: Identify the user account to test${NC}"
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
echo "Checking premium status..."
PREMIUM_INFO=$(docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -t -c "
  SELECT 
    u.\"premiumId\",
    p.tier,
    p.\"lemonSqueezyRenewsAt\",
    p.\"bulkUnsubscribeAccess\",
    p.\"aiAutomationAccess\",
    p.\"coldEmailBlockerAccess\",
    p.\"emailAccountsAccess\"
  FROM \"User\" u
  LEFT JOIN \"Premium\" p ON u.\"premiumId\" = p.id
  WHERE u.email = '$USER_EMAIL';
")

PREMIUM_ID=$(echo "$PREMIUM_INFO" | head -n 1 | tr -d ' ')

if [[ -z "$PREMIUM_ID" || "$PREMIUM_ID" == "|||||" ]]; then
  echo -e "${RED}❌ User does not have premium access${NC}"
  echo "Please run ./enable-premium-db.sh first to enable premium features."
  exit 1
fi

# Extract premium details
TIER=$(echo "$PREMIUM_INFO" | awk -F '|' '{print $2}' | tr -d ' ')
EXPIRES=$(echo "$PREMIUM_INFO" | awk -F '|' '{print $3}' | tr -d ' ')
BULK_UNSUBSCRIBE=$(echo "$PREMIUM_INFO" | awk -F '|' '{print $4}' | tr -d ' ')
AI_AUTOMATION=$(echo "$PREMIUM_INFO" | awk -F '|' '{print $5}' | tr -d ' ')
COLD_EMAIL=$(echo "$PREMIUM_INFO" | awk -F '|' '{print $6}' | tr -d ' ')
EMAIL_ACCOUNTS=$(echo "$PREMIUM_INFO" | awk -F '|' '{print $7}' | tr -d ' ')

echo -e "${GREEN}✅ Premium access confirmed${NC}"
echo ""
echo -e "${BLUE}📋 PREMIUM SUBSCRIPTION DETAILS 📋${NC}"
echo -e "User: ${GREEN}$USER_EMAIL${NC}"
echo -e "Premium ID: ${GREEN}$PREMIUM_ID${NC}"
echo -e "Tier: ${GREEN}$TIER${NC}"
echo -e "Expires: ${GREEN}$EXPIRES${NC}"
echo -e "Bulk Unsubscribe: ${GREEN}$BULK_UNSUBSCRIBE${NC}"
echo -e "AI Automation: ${GREEN}$AI_AUTOMATION${NC}"
echo -e "Cold Email Blocker: ${GREEN}$COLD_EMAIL${NC}"
echo -e "Email Accounts: ${GREEN}$EMAIL_ACCOUNTS${NC}"
echo ""

# Check if application is running
echo -e "${YELLOW}Step 2: Checking if application is running...${NC}"
if curl -s http://localhost:3000 > /dev/null; then
  echo -e "${GREEN}✅ Application is running at http://localhost:3000${NC}"
else
  echo -e "${YELLOW}⚠️ Application does not appear to be running${NC}"
  echo "Would you like to start it now?"
  read -p "Start application? (y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Starting application..."
    ./start-local.sh &
    
    # Wait for application to start
    echo "Waiting for application to start (this may take a minute)..."
    for i in {1..60}; do
      if curl -s http://localhost:3000 > /dev/null; then
        echo -e "${GREEN}✅ Application started successfully${NC}"
        break
      fi
      sleep 1
      if [ $i -eq 60 ]; then
        echo -e "${RED}❌ Application failed to start in time${NC}"
        echo "Please start it manually with ./start-local.sh"
        exit 1
      fi
    done
  else
    echo -e "${YELLOW}⚠️ Skipping application start${NC}"
    echo "Please start the application manually with ./start-local.sh before testing features."
    exit 0
  fi
fi

# Premium features test checklist
echo ""
echo -e "${BLUE}🔍 PREMIUM FEATURES TEST CHECKLIST 🔍${NC}"
echo "Please complete the following tests in your browser:"
echo ""

echo -e "${YELLOW}1. Bulk Unsubscribe Test${NC}"
echo "   a. Navigate to http://localhost:3000/bulk-unsubscribe"
echo "   b. Verify you can see the bulk unsubscribe interface"
echo "   c. Check that you can select multiple emails for unsubscribing"
echo "   d. Verify there are no upgrade prompts or limitations"
read -p "Did the Bulk Unsubscribe feature work correctly? (y/n/s=skip): " -n 1 -r BULK_TEST
echo ""
if [[ $BULK_TEST =~ ^[Yy]$ ]]; then
  echo -e "${GREEN}✅ Bulk Unsubscribe test passed${NC}"
elif [[ $BULK_TEST =~ ^[Ss]$ ]]; then
  echo -e "${YELLOW}⚠️ Bulk Unsubscribe test skipped${NC}"
else
  echo -e "${RED}❌ Bulk Unsubscribe test failed${NC}"
fi
echo ""

echo -e "${YELLOW}2. AI Automation Test${NC}"
echo "   a. Navigate to http://localhost:3000/ai"
echo "   b. Verify you can access AI automation features"
echo "   c. Check that you can create or modify AI rules"
echo "   d. Verify there are no upgrade prompts or limitations"
read -p "Did the AI Automation feature work correctly? (y/n/s=skip): " -n 1 -r AI_TEST
echo ""
if [[ $AI_TEST =~ ^[Yy]$ ]]; then
  echo -e "${GREEN}✅ AI Automation test passed${NC}"
elif [[ $AI_TEST =~ ^[Ss]$ ]]; then
  echo -e "${YELLOW}⚠️ AI Automation test skipped${NC}"
else
  echo -e "${RED}❌ AI Automation test failed${NC}"
fi
echo ""

echo -e "${YELLOW}3. Cold Email Blocker Test${NC}"
echo "   a. Navigate to http://localhost:3000/cold-email-blocker"
echo "   b. Verify you can access cold email blocker settings"
echo "   c. Check that you can enable/disable the feature"
echo "   d. Verify there are no upgrade prompts or limitations"
read -p "Did the Cold Email Blocker feature work correctly? (y/n/s=skip): " -n 1 -r COLD_TEST
echo ""
if [[ $COLD_TEST =~ ^[Yy]$ ]]; then
  echo -e "${GREEN}✅ Cold Email Blocker test passed${NC}"
elif [[ $COLD_TEST =~ ^[Ss]$ ]]; then
  echo -e "${YELLOW}⚠️ Cold Email Blocker test skipped${NC}"
else
  echo -e "${RED}❌ Cold Email Blocker test failed${NC}"
fi
echo ""

echo -e "${YELLOW}4. Email Accounts Limit Test${NC}"
echo "   a. Navigate to http://localhost:3000/settings"
echo "   b. Check if you can add multiple email accounts"
echo "   c. Verify there are no account limit restrictions"
read -p "Did the Email Accounts feature work correctly? (y/n/s=skip): " -n 1 -r ACCOUNTS_TEST
echo ""
if [[ $ACCOUNTS_TEST =~ ^[Yy]$ ]]; then
  echo -e "${GREEN}✅ Email Accounts test passed${NC}"
elif [[ $ACCOUNTS_TEST =~ ^[Ss]$ ]]; then
  echo -e "${YELLOW}⚠️ Email Accounts test skipped${NC}"
else
  echo -e "${RED}❌ Email Accounts test failed${NC}"
fi
echo ""

echo -e "${YELLOW}5. Upgrade Prompts Test${NC}"
echo "   a. Navigate through various sections of the application"
echo "   b. Verify there are no upgrade prompts or banners anywhere"
read -p "Did you see any upgrade prompts or limitations? (y/n/s=skip): " -n 1 -r UPGRADE_TEST
echo ""
if [[ $UPGRADE_TEST =~ ^[Nn]$ ]]; then
  echo -e "${GREEN}✅ No upgrade prompts found${NC}"
elif [[ $UPGRADE_TEST =~ ^[Ss]$ ]]; then
  echo -e "${YELLOW}⚠️ Upgrade prompts test skipped${NC}"
else
  echo -e "${RED}❌ Upgrade prompts were found${NC}"
  read -p "Please describe where you saw upgrade prompts: " UPGRADE_LOCATION
  echo "Upgrade prompts found at: $UPGRADE_LOCATION" >> premium-test-results.log
fi
echo ""

# Test summary
echo -e "${BLUE}📋 PREMIUM FEATURES TEST SUMMARY 📋${NC}"
PASSED=0
FAILED=0
SKIPPED=0

for TEST in "$BULK_TEST" "$AI_TEST" "$COLD_TEST" "$ACCOUNTS_TEST" "$UPGRADE_TEST"; do
  if [[ $TEST =~ ^[Yy]$ || ($TEST =~ ^[Nn]$ && $TEST == "$UPGRADE_TEST") ]]; then
    PASSED=$((PASSED+1))
  elif [[ $TEST =~ ^[Ss]$ ]]; then
    SKIPPED=$((SKIPPED+1))
  else
    FAILED=$((FAILED+1))
  fi
done

echo -e "Tests passed: ${GREEN}$PASSED${NC}"
echo -e "Tests failed: ${RED}$FAILED${NC}"
echo -e "Tests skipped: ${YELLOW}$SKIPPED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}✅ PREMIUM FEATURES TESTING SUCCESSFUL${NC}"
  echo "All tested premium features are working correctly."
  
  # Record test results in a log file
  echo "$(date): Premium features testing completed successfully for $USER_EMAIL" >> premium-test-results.log
else
  echo -e "${RED}❌ PREMIUM FEATURES TESTING INCOMPLETE${NC}"
  echo "Some premium features are not working correctly."
  echo "Please check the logs and fix any issues."
  
  # Record test results in a log file
  echo "$(date): Premium features testing failed for $USER_EMAIL. $FAILED tests failed." >> premium-test-results.log
fi

echo ""
echo "You have now completed Task 12:"
echo "Implementing and testing premium access via database modification."
