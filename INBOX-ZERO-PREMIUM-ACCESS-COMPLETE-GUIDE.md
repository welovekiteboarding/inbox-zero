# Comprehensive Guide to Premium Access Options for Inbox Zero

This document provides a complete overview of all available options for enabling premium features in your local Inbox Zero development environment, along with database backup and recovery strategies to ensure data safety.

## Table of Contents

1. [Introduction](#introduction)
2. [Comparing the Three Premium Access Approaches](#comparing-the-three-premium-access-approaches)
   - [Approach 1: Direct Database Modification](#approach-1-direct-database-modification)
   - [Approach 2: Code Patching](#approach-2-code-patching)
   - [Approach 3: Local Subscription System](#approach-3-local-subscription-system)
   - [Feature Comparison](#feature-comparison)
3. [Implementation Guides](#implementation-guides)
   - [Implementing Direct Database Modification](#implementing-direct-database-modification)
   - [Implementing Code Patching](#implementing-code-patching)
   - [Implementing Local Subscription System](#implementing-local-subscription-system)
4. [Database Safety and Recovery](#database-safety-and-recovery)
   - [Creating Database Backups](#creating-database-backups)
   - [Restoring from Backups](#restoring-from-backups)
   - [Undoing Premium Changes](#undoing-premium-changes)
   - [Complete Database Reset](#complete-database-reset)
   - [Automated Safety Workflows](#automated-safety-workflows)
5. [Development Workflow Best Practices](#development-workflow-best-practices)
   - [Git Branch Strategy](#git-branch-strategy)
   - [Testing Different Approaches](#testing-different-approaches)
   - [Keeping Your Fork Updated](#keeping-your-fork-updated)
6. [Troubleshooting](#troubleshooting)
   - [Common Issues and Solutions](#common-issues-and-solutions)
   - [Diagnosing Database Problems](#diagnosing-database-problems)
   - [Recovery Strategies](#recovery-strategies)
7. [Conclusion](#conclusion)

## Introduction

Inbox Zero uses a subscription-based model to control access to premium features like bulk unsubscribing, AI automation, and the cold email blocker. For local development, it's helpful to have full access to these features without implementing the actual payment processing system.

This guide presents three distinct approaches to enabling premium access in your local environment, each with its own advantages and trade-offs. Additionally, it covers comprehensive database safety measures to ensure you can recover from any issues that might arise during implementation.

## Comparing the Three Premium Access Approaches

### Approach 1: Direct Database Modification

**Overview**: This approach directly inserts the necessary records into your database to make the application think you have purchased a premium subscription.

**Key Benefits**:

- Simplest method with minimal implementation effort
- No code changes required
- Uses the exact same database structure as real subscriptions
- Changes persist across application restarts

**How It Works**:

1. Creates a Premium record in the database with a far-future expiration date
2. Sets all feature access flags to "UNLOCKED"
3. Links this Premium record to your User record
4. The application's existing premium checks see this as a valid subscription

**Implementation Complexity**: Low - Just execute a few SQL commands

**Best For**: Quick setup with minimal changes

### Approach 2: Code Patching

**Overview**: This approach modifies the code that checks for premium status to always return true, bypassing the need for database records entirely.

**Key Benefits**:

- Works regardless of database state
- Applies globally to all users
- No need for database modifications
- Makes it impossible for premium checks to fail

**How It Works**:

1. Patches utility functions that check premium status
2. Disables redirect mechanisms for upgrade pages
3. Prevents premium modal dialogs from appearing
4. Forces feature access checks to return positive results

**Implementation Complexity**: Medium - Requires code modifications

**Best For**: Situations where you want all users to automatically have premium access

### Approach 3: Local Subscription System

**Overview**: This approach implements a more sophisticated solution that preserves the subscription architecture.

**Key Benefits**:

- Preserves the original architecture for future commercialization
- Allows testing different premium tiers
- Provides a UI for managing subscriptions
- Most similar to how a real deployment would work

**How It Works**:

1. Creates a development-only API for managing subscriptions
2. Builds a web UI for subscription management
3. Uses the same database models and relationships
4. Bypasses only the payment processing part

**Implementation Complexity**: High - Requires new API routes and UI components

**Best For**: Testing the full subscription flow or planning to commercialize

### Feature Comparison

| Feature               | Direct Database | Code Patching      | Local Subscription |
| --------------------- | --------------- | ------------------ | ------------------ |
| Implementation Effort | Low             | Medium             | High               |
| Code Changes Required | None            | Yes                | Yes                |
| Database Changes      | Yes             | No                 | Yes                |
| Persistence           | Until DB Reset  | Until Code Changes | Until DB Reset     |
| UI for Management     | No              | No                 | Yes                |
| Multiple Tiers        | Manual DB Edit  | No                 | Yes, via UI        |
| All Users Get Premium | No, per-user    | Yes, all users     | No, per-user       |
| Recovery Complexity   | Medium          | Low                | High               |
| Authenticity          | High            | Low                | Highest            |

## Implementation Guides

### Implementing Direct Database Modification

The complete implementation details are available in the [DB-DIRECT-PREMIUM-GUIDE.md](DB-DIRECT-PREMIUM-GUIDE.md) file. This section provides a summary of the key steps:

1. **Create the enable-premium-directly.sh script**:

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

2. **Create the matching disable script**:

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

3. **Create a toggle script for easy switching**:

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

4. **Run the script to enable premium features**:

```bash
./enable-premium-directly.sh
```

5. **Enter your email when prompted, and premium features will be enabled**

### Implementing Code Patching

The complete implementation details are available in the [PREMIUM-PATCHING-GUIDE.md](PREMIUM-PATCHING-GUIDE.md) file. This section provides a summary of the key steps:

1. **Use the provided patching script**:

The repository already includes a script at `patching/modify-premium-checks.sh` that can patch the necessary files to bypass premium checks.

2. **Run the script:**

```bash
./patching/modify-premium-checks.sh
```

This script will:

- Modify utility functions that check premium status to always return true
- Disable redirect mechanisms for upgrade pages
- Prevent premium modal dialogs from appearing

3. **Restart the application after patching**:

```bash
./stop-local.sh
./start-local.sh
```

### Implementing Local Subscription System

The complete implementation details are available in the [LOCAL-SUBSCRIPTION-GUIDE.md](LOCAL-SUBSCRIPTION-GUIDE.md) and [LOCAL-SUBSCRIPTION-GUIDE-PART2.md](LOCAL-SUBSCRIPTION-GUIDE-PART2.md) files. This is the most comprehensive approach that preserves the original architecture.

Due to the complexity of this approach, please refer to the dedicated guide files for the complete implementation steps.

## Database Safety and Recovery

### Creating Database Backups

Before making any changes to your database, it's crucial to create backups. Here's a script to create PostgreSQL backups:

```bash
cat > backup-postgres.sh << 'EOL'
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
EOL

chmod +x backup-postgres.sh
```

Running this script (`./backup-postgres.sh`) will create a full backup of your PostgreSQL database in the `./db_backups` directory.

### Restoring from Backups

If you need to restore from a backup, you can use this script:

```bash
cat > restore-postgres.sh << 'EOL'
#!/bin/bash
# restore-postgres.sh - Restore PostgreSQL database from backup

# Check if backup file is provided
if [ $# -ne 1 ]; then
  echo "❌ Error: Please provide the backup file to restore."
  echo "Usage: $0 <backup_file.sql>"
  exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
  echo "❌ Error: Backup file not found: $BACKUP_FILE"
  exit 1
fi

echo "⚠️ WARNING: This will overwrite your current database!"
read -p "Are you sure you want to continue? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "🛑 Database restore aborted."
  exit 0
fi

echo "🔄 Stopping application..."
./stop-local.sh

echo "🔄 Starting only PostgreSQL container..."
docker-compose up -d postgres

echo "⏳ Waiting for PostgreSQL to start..."
sleep 5

echo "🔄 Restoring database from backup: $BACKUP_FILE"
cat "$BACKUP_FILE" | docker exec -i inbox-zero-postgres-1 psql -U inbox -d inboxdb

if [ $? -eq 0 ]; then
  echo "✅ Database restored successfully!"
else
  echo "❌ Error: Failed to restore database."
fi

echo "🔄 Restarting application..."
docker-compose down
./start-local.sh
EOL

chmod +x restore-postgres.sh
```

To restore from a backup, run:

```bash
./restore-postgres.sh ./db_backups/your_backup_file.sql
```

### Undoing Premium Changes

If you need to undo premium changes without a full database restore, you can use the `disable-premium-directly.sh` script provided in the [Direct Database Modification section](#implementing-direct-database-modification).

This script will safely remove premium access from a specific user without affecting other data:

```bash
./disable-premium-directly.sh
```

### Complete Database Reset

As a last resort, if your database becomes severely corrupted or you want to start fresh, you can completely reset it:

```bash
cat > reset-database.sh << 'EOL'
#!/bin/bash
# reset-database.sh - Completely reset the PostgreSQL database

echo "⚠️ WARNING: This will completely reset your database and delete ALL data!"
echo "    All emails, accounts, and settings will be lost."
read -p "Are you absolutely sure you want to continue? (type 'RESET' to confirm): " CONFIRM

if [[ "$CONFIRM" != "RESET" ]]; then
  echo "🛑 Database reset aborted."
  exit 1
fi

echo "🗑️ Stopping Docker containers..."
docker-compose down

echo "🗑️ Removing PostgreSQL volume..."
docker volume rm inbox-zero_postgres-data

echo "🚀 Starting containers with fresh database..."
docker-compose up -d

echo "⏳ Waiting for PostgreSQL to start..."
sleep 5

echo "🔄 Running database migrations..."
cd apps/web
npx prisma migrate deploy
cd ../..

echo "✅ Database has been completely reset!"
echo "   You will need to sign up again to create a new account."
EOL

chmod +x reset-database.sh
```

Running this script (`./reset-database.sh`) will:

1. Stop all containers
2. Delete the PostgreSQL volume
3. Start fresh containers
4. Run database migrations
5. Reset the application to its initial state

### Automated Safety Workflows

For maximum safety when implementing premium access changes, create a comprehensive safety script that combines backup and implementation:

```bash
cat > safe-premium-enable.sh << 'EOL'
#!/bin/bash
# safe-premium-enable.sh - Enable premium features with automatic backup

# 1. Create backup first
echo "🔒 Safety Step: Creating database backup before making changes..."
./backup-postgres.sh

# Check if backup was successful
if [ $? -ne 0 ]; then
  echo "❌ Backup failed! Aborting premium implementation for safety."
  exit 1
fi

echo ""
echo "🛡️ Backup created successfully. Proceeding with premium implementation."
echo ""

# 2. Now implement premium features
./enable-premium-directly.sh

echo ""
echo "📝 Summary of Actions:"
echo "  - Database backup created"
echo "  - Premium features implemented"
echo ""
echo "🔄 If you need to revert these changes, run:"
echo "  ./disable-premium-directly.sh"
echo ""
echo "🔙 Or if you need to fully restore from backup, run:"
echo "  ./restore-postgres.sh [backup-file]"
EOL

chmod +x safe-premium-enable.sh
```

This script ensures you always have a backup before making premium changes.

## Development Workflow Best Practices

### Git Branch Strategy

When working with premium access modifications, it's important to use an effective branch strategy:

1. **Main Branch**: Keep this as a direct mirror of the upstream repository

   ```bash
   git checkout main
   git pull origin main  # Pull from original repo
   ```

2. **Feature Branches**: Create dedicated branches for different approaches

   ```bash
   # For Redis fixes
   git checkout -b redis-fixes

   # For code patching approach
   git checkout -b premium-patching

   # For database approach (though this doesn't change code)
   git checkout -b db-premium

   # For local subscription system
   git checkout -b subscription-system
   ```

3. **When to Use Different Branches**:
   - The **Database Modification** approach doesn't require code changes, so you can apply it using scripts without needing a dedicated branch
   - The **Code Patching** approach modifies source files, so it should have its own branch
   - The **Local Subscription** approach adds new files and significant functionality, so it definitely needs its own branch

### Testing Different Approaches

To effectively test different premium access approaches:

1. **Use Git to Switch Between Approaches**:

   ```bash
   # Switch to code patching approach
   git checkout premium-patching

   # Switch to local subscription system
   git checkout subscription-system

   # Return to clean state
   git checkout main
   ```

2. **Reset Database Between Tests**:

   ```bash
   # Option 1: Complete reset (all data lost)
   ./reset-database.sh

   # Option 2: Just disable premium for specific user
   ./disable-premium-directly.sh
   ```

3. **Clear Browser Cache/Cookies**:
   - Between testing different approaches, clear your browser's cache and cookies
   - This ensures no leftover state from previous tests

### Keeping Your Fork Updated

To keep your fork up-to-date with the original repository:

1. **Add the Original Repo as a Remote**:

   ```bash
   git remote add upstream https://github.com/elie222/inbox-zero.git
   ```

2. **Update Your Main Branch**:

   ```bash
   git checkout main
   git fetch upstream
   git merge upstream/main
   git push fork main
   ```

3. **Update Your Feature Branches**:
   ```bash
   git checkout your-feature-branch
   git merge main
   # Resolve any conflicts
   git push fork your-feature-branch
   ```

## Troubleshooting

### Common Issues and Solutions

1. **Problem**: Premium features still not accessible after implementation
   **Solution**:

   - Verify that your user account is correctly linked to a premium record
   - Check for JavaScript errors in the browser console
   - Try clearing browser cache and cookies
   - Ensure you're logged in with the correct account

2. **Problem**: Database errors during SQL execution
   **Solution**:

   - Check PostgreSQL container is running: `docker ps | grep postgres`
   - Verify database connection parameters in `.env.local`
   - Check SQL syntax for compatibility with your PostgreSQL version

3. **Problem**: Application crashes after code patching
   **Solution**:
   - Restore original files from git: `git checkout -- path/to/modified/files`
   - Or restore from backup: `git stash apply stash_name`
   - Consider using the database approach instead, which doesn't modify code

### Diagnosing Database Problems

If you encounter database issues:

1. **Connect to the PostgreSQL Container**:

   ```bash
   docker exec -it inbox-zero-postgres-1 bash
   ```

2. **Log in to PostgreSQL**:

   ```bash
   psql -U inbox -d inboxdb
   ```

3. **Useful PostgreSQL Commands**:

   ```sql
   -- List tables
   \dt

   -- Examine Premium records
   SELECT * FROM "Premium";

   -- Check user premium associations
   SELECT id, email, "premiumId" FROM "User";

   -- View specific user's premium status
   SELECT u.email, u."premiumId", p.tier, p."lemonSqueezyRenewsAt"
   FROM "User" u
   LEFT JOIN "Premium" p ON u."premiumId" = p.id
   WHERE u.email = 'your-email@example.com';
   ```

### Recovery Strategies

When things go wrong, follow this escalating recovery strategy:

1. **Level 1**: Try specific fixes first

   - For DB approach: Run `disable-premium-directly.sh`
   - For code patching: Restore files from git
   - For subscription system: Remove added endpoints

2. **Level 2**: Restore from a recent backup

   ```bash
   ./restore-postgres.sh ./db_backups/your_backup_file.sql
   ```

3. **Level 3**: Reset specific tables

   ```sql
   -- Connect to database and run:
   DELETE FROM "Premium";
   UPDATE "User" SET "premiumId" = NULL, "premiumAdminId" = NULL;
   ```

4. **Level 4**: Complete database reset (nuclear option)
   ```bash
   ./reset-database.sh
   ```

## Conclusion

This document has provided a comprehensive overview of the three approaches to enabling premium features in your local Inbox Zero development environment:

1. **Direct Database Modification**: The simplest approach, modifying database records directly
2. **Code Patching**: Modifying the code that checks for premium status
3. **Local Subscription System**: A more sophisticated approach that preserves the original architecture

Each approach has its own advantages and use cases, and you can choose the one that best fits your development needs.

Additionally, we've covered critical database safety measures to ensure you can recover from any issues that might arise during implementation. By following the backup procedures and using the provided scripts, you can experiment with different approaches while minimizing the risk of data loss or corruption.

Remember to always create backups before making significant changes, and to use the appropriate git workflow to maintain a clean separation between different approaches and your main codebase.
