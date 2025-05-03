# Direct Database Modification for Premium Access in Inbox Zero

This guide provides a simple approach to directly modify your database records to enable premium features in Inbox Zero without implementing the subscription service or making any payments.

## Overview

Instead of patching code or creating a local subscription system, this approach directly inserts the necessary records into your database to make the application think you have purchased a premium subscription.

The core advantage of this approach is its simplicity:

- No code changes required
- No need to implement subscription UI or API
- Very few steps to execute
- Works exactly like a real subscription would

## Understanding the Database Structure

Before making modifications, it's important to understand how premium access is stored in the database:

1. **Premium Table**: Stores subscription details and feature access flags
2. **User Table**: Contains a reference (`premiumId`) to a Premium record
3. **Relational Structure**: One Premium record can be associated with multiple users

## Step-by-Step Implementation

### 1. Prerequisites

- A local development environment for Inbox Zero
- Running PostgreSQL database (using Docker Compose)
- An existing user account in the application

### 2. Create a Script to Update the Database

Create a script file that will insert premium records and update your user account:

```bash
cat > enable-premium-directly.sh << 'EOL'
#!/bin/bash
# enable-premium-directly.sh - Directly modify database records to enable premium features

echo "🔧 Enabling premium features by direct database modification..."

# Configuration
USER_EMAIL=""  # Will be set interactively

# Get user email
read -p "Enter your Inbox Zero account email: " USER_EMAIL
if [[ -z "$USER_EMAIL" ]]; then
  echo "❌ No email provided. Aborting."
  exit 1
fi

echo "🔍 Enabling premium features for account: $USER_EMAIL"

# 1. Check if the user exists
USER_EXISTS=$(docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -t -c "SELECT COUNT(*) FROM \"User\" WHERE email = '$USER_EMAIL';")

if [[ "$USER_EXISTS" -eq 0 ]]; then
  echo "❌ Error: User with email $USER_EMAIL not found in database."
  echo "   Please make sure you've signed up and the email is correct."
  exit 1
fi

# 2. Create SQL commands to setup premium
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
  p."coldEmailBlockerAccess"
FROM
  "User" u
JOIN
  "Premium" p ON u."premiumId" = p.id
WHERE
  u.email = '$USER_EMAIL';
EOSQL
)

# 3. Execute the SQL
echo "$SQL_COMMANDS" | docker exec -i inbox-zero-postgres-1 psql -U inbox -d inboxdb

# 4. Check if the operation was successful
if [ $? -eq 0 ]; then
  echo "✅ Premium features successfully enabled for $USER_EMAIL"
  echo "   Premium subscription will be valid for 10 years!"
  echo ""
  echo "Note: If the application is currently running, you may need to refresh"
  echo "      your browser or sign out and sign back in to see the changes."
else
  echo "❌ Error: Failed to enable premium features."
  echo "   Please check the error message above."
fi
EOL

chmod +x enable-premium-directly.sh
```

### 3. Create a Script to Disable Premium

Create a complementary script to remove premium access if needed:

```bash
cat > disable-premium-directly.sh << 'EOL'
#!/bin/bash
# disable-premium-directly.sh - Remove premium access by direct database modification

echo "🔧 Disabling premium features by direct database modification..."

# Configuration
USER_EMAIL=""  # Will be set interactively

# Get user email
read -p "Enter your Inbox Zero account email: " USER_EMAIL
if [[ -z "$USER_EMAIL" ]]; then
  echo "❌ No email provided. Aborting."
  exit 1
fi

echo "🔍 Disabling premium features for account: $USER_EMAIL"

# 1. Check if the user exists
USER_EXISTS=$(docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -t -c "SELECT COUNT(*) FROM \"User\" WHERE email = '$USER_EMAIL';")

if [[ "$USER_EXISTS" -eq 0 ]]; then
  echo "❌ Error: User with email $USER_EMAIL not found in database."
  echo "   Please make sure you've signed up and the email is correct."
  exit 1
fi

# 2. Create SQL commands to remove premium
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

# 3. Execute the SQL
echo "$SQL_COMMANDS" | docker exec -i inbox-zero-postgres-1 psql -U inbox -d inboxdb

# 4. Check if the operation was successful
if [ $? -eq 0 ]; then
  echo "✅ Premium features successfully disabled for $USER_EMAIL"
  echo ""
  echo "Note: If the application is currently running, you may need to refresh"
  echo "      your browser or sign out and sign back in to see the changes."
else
  echo "❌ Error: Failed to disable premium features."
  echo "   Please check the error message above."
fi
EOL

chmod +x disable-premium-directly.sh
```

### 4. Create a Toggle Script for Easy Switching

Create a script that lets you easily toggle premium features on and off:

```bash
cat > toggle-premium-directly.sh << 'EOL'
#!/bin/bash
# toggle-premium-directly.sh - Toggle premium features on/off via direct database modification

echo "🔄 Toggling premium features via direct database modification..."

# Configuration
USER_EMAIL=""  # Will be set interactively

# Get user email
read -p "Enter your Inbox Zero account email: " USER_EMAIL
if [[ -z "$USER_EMAIL" ]]; then
  echo "❌ No email provided. Aborting."
  exit 1
fi

# Check if the user exists
USER_EXISTS=$(docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -t -c "SELECT COUNT(*) FROM \"User\" WHERE email = '$USER_EMAIL';")

if [[ "$USER_EXISTS" -eq 0 ]]; then
  echo "❌ Error: User with email $USER_EMAIL not found in database."
  echo "   Please make sure you've signed up and the email is correct."
  exit 1
fi

# Check if user has premium
HAS_PREMIUM=$(docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -t -c "SELECT \"premiumId\" IS NOT NULL FROM \"User\" WHERE email = '$USER_EMAIL';")
HAS_PREMIUM=$(echo $HAS_PREMIUM | tr -d [:space:])

if [[ "$HAS_PREMIUM" == "t" ]]; then
  echo "🔽 User currently has premium access. Disabling..."

  # Create SQL commands to remove premium
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
EOSQL
  )

  # Execute the SQL
  echo "$SQL_COMMANDS" | docker exec -i inbox-zero-postgres-1 psql -U inbox -d inboxdb

  echo "✅ Premium features disabled"

else
  echo "🔼 User currently does NOT have premium access. Enabling..."

  # Create SQL commands to setup premium
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
EOSQL
  )

  # Execute the SQL
  echo "$SQL_COMMANDS" | docker exec -i inbox-zero-postgres-1 psql -U inbox -d inboxdb

  echo "✅ Premium features enabled"
fi

echo ""
echo "🔄 Toggle complete! The changes should take effect immediately."
echo "   You may need to refresh your browser to see the changes."
EOL

chmod +x toggle-premium-directly.sh
```

## Usage Instructions

### Enabling Premium

1. Make sure your Docker containers are running:

```bash
docker-compose up -d
```

2. Sign up/in to Inbox Zero at least once to create a user account.

3. Run the script and enter your email when prompted:

```bash
./enable-premium-directly.sh
```

The script will:

- Create a new Premium record with a 10-year validity period
- Link this Premium record to your user account
- Set all feature access flags to "UNLOCKED"

### Disabling Premium

If you need to see how the application behaves without premium:

```bash
./disable-premium-directly.sh
```

### Toggling Premium On/Off

For quick switching between premium and free mode:

```bash
./toggle-premium-directly.sh
```

## How It Works

This solution works by directly modifying the same database records that would be modified during a normal subscription process:

1. The `Premium` table gets a new record with:

   - A far-future expiration date (10 years)
   - All feature access flags set to "UNLOCKED"
   - Tier set to "LIFETIME" (the highest tier)

2. Your `User` record gets updated with:
   - A reference to the new Premium record in the "premiumId" field
   - Admin privileges for the Premium in the "premiumAdminId" field

When the application checks for premium status, it queries these database records:

- `isPremium()` checks if the premium record exists and isn't expired
- `hasAiAccess()` and similar functions check the feature access flags

Since we've inserted the correct records with the right values, the application behaves exactly as if you had a valid subscription.

## Advantages of This Approach

- **Simplicity**: Just one script to run - no code changes or APIs needed
- **Authenticity**: Uses the same database structure as real subscriptions
- **Reliability**: Less likely to break with application updates
- **Compatibility**: Works perfectly with existing premium check functions
- **Persistence**: Changes persist across application restarts

## Conclusion

This direct database modification approach is the simplest and most reliable way to enable premium features for local development without implementing the subscription system or making payments.

It leverages your understanding of the database structure to insert the exact records needed, letting the application's existing premium check functions work normally.
