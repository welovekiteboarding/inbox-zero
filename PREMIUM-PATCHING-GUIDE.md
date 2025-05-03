# Comprehensive Guide to Patching Inbox Zero for Premium Local Use

This guide provides detailed instructions for implementing all necessary modifications to make Inbox Zero completely free for local development by removing premium tier limitations, upgrade modals, and implementing required utility scripts.

## Overview of Premium System in Inbox Zero

Before diving into the patching process, it's important to understand how the premium system works in Inbox Zero:

1. **Database Structure**:

   - `User` model has a relationship to the `Premium` model through the `premiumId` field
   - `Premium` model stores subscription details and feature access flags

2. **Feature Access Control**:

   - Premium features are controlled through the `FeatureAccess` enum (LOCKED, UNLOCKED, UNLOCKED_WITH_API_KEY)
   - Each feature has its own access flag in the Premium model

3. **Premium Check System**:
   - Client-side checks in `utils/premium/index.ts`
   - Server-side checks in `utils/premium/server.ts`
   - Upgrade redirects in `utils/premium/check-and-redirect-for-upgrade.tsx`
   - Premium modal in `app/(app)/premium/PremiumModal.tsx`

## Detailed Patching Process

### Step 1: Create Backup Directory Structure

```bash
mkdir -p patching/backup/apps/web/utils/premium
mkdir -p patching/backup/apps/web/app/\(app\)/premium
```

This creates the necessary directory structure to store backups of files we'll modify.

### Step 2: Backup Original Files

Backup each file before modifying:

```bash
# Backup premium utility files
cp apps/web/utils/premium/index.ts patching/backup/apps/web/utils/premium/
cp apps/web/utils/premium/server.ts patching/backup/apps/web/utils/premium/
cp apps/web/utils/premium/check-and-redirect-for-upgrade.tsx patching/backup/apps/web/utils/premium/

# Backup premium modal file
cp apps/web/app/\(app\)/premium/PremiumModal.tsx patching/backup/apps/web/app/\(app\)/premium/
```

### Step 3: Modify `utils/premium/index.ts`

This file contains the core client-side premium checking functions.

1. Create a new version of the file with all premium checks returning true:

```bash
cat > apps/web/utils/premium/index.ts << 'EOL'
import { FeatureAccess, type Premium, PremiumTier } from "@prisma/client";

// PATCHED for local development - Always return premium status
export const isPremium = () => true;

// Always return LIFETIME tier (highest tier)
export const getUserTier = () => PremiumTier.LIFETIME;

// Always return true for admin check
export const isAdminForPremium = () => true;

// Always allow unsubscribe access
export const hasUnsubscribeAccess = () => true;

// Always allow AI access
export const hasAiAccess = () => true;

// Always allow cold email access
export const hasColdEmailAccess = () => true;

// Always return that we're on the highest tier
export function isOnHigherTier() {
  return true;
}
EOL
```

### Step 4: Modify `utils/premium/server.ts`

This file handles server-side premium checks and tier management.

```bash
cat > apps/web/utils/premium/server.ts << 'EOL'
import prisma from "@/utils/prisma";
import { FeatureAccess, PremiumTier } from "@prisma/client";

// PATCHED for local development - All server-side premium functions modified

// Still allow legitimate upgrades to work, but for local users
// we'll always return full premium access
export async function upgradeToPremium(options: any) {
  const { userId, ...rest } = options;

  // Continue to allow normal upgrade process for legitimate requests
  const user = await prisma.user.findUnique({
    where: { id: options.userId },
    select: { premiumId: true },
  });

  if (!user) throw new Error(`User not found for id ${options.userId}`);

  // Set all features to UNLOCKED
  const data = {
    ...rest,
    lemonSqueezyRenewsAt: new Date(Date.now() + 10 * 365 * 24 * 60 * 60 * 1000), // 10 years
    tier: PremiumTier.LIFETIME,
    bulkUnsubscribeAccess: FeatureAccess.UNLOCKED,
    aiAutomationAccess: FeatureAccess.UNLOCKED,
    coldEmailBlockerAccess: FeatureAccess.UNLOCKED,
    emailAccountsAccess: 999,
  };

  if (user.premiumId) {
    return await prisma.premium.update({
      where: { id: user.premiumId },
      data,
      select: { users: { select: { email: true } } },
    });
  }

  return await prisma.premium.create({
    data: {
      users: { connect: { id: options.userId } },
      admins: { connect: { id: options.userId } },
      ...data,
    },
    select: { users: { select: { email: true } } },
  });
}

// Modified to always grant premium access for local development
export async function extendPremium(options: any) {
  // We'll still update the database record, but with a far future date
  return await prisma.premium.update({
    where: { id: options.premiumId },
    data: {
      lemonSqueezyRenewsAt: new Date(Date.now() + 10 * 365 * 24 * 60 * 60 * 1000), // 10 years
    },
    select: {
      users: {
        select: { email: true },
      },
    },
  });
}

// Modified to not actually cancel premium for local development
export async function cancelPremium(options: any) {
  // We'll still update the database for tracking, but keep premium active
  return await prisma.premium.update({
    where: { id: options.premiumId },
    data: {
      // Set to a far future date instead of the actual end date
      lemonSqueezyRenewsAt: new Date(Date.now() + 10 * 365 * 24 * 60 * 60 * 1000),
    },
    select: {
      users: {
        select: { email: true },
      },
    },
  });
}

// Continue to allow email account access updates
export async function editEmailAccountsAccess(options: any) {
  const { count } = options;
  if (!count) return;

  // For local development, always set to a high number instead of incrementing
  return await prisma.premium.update({
    where: { id: options.premiumId },
    data: {
      emailAccountsAccess: 999, // Always set to maximum
    },
    select: {
      users: {
        select: { email: true },
      },
    },
  });
}

// Modified to always return all features unlocked
function getTierAccess(tier: PremiumTier) {
  return {
    bulkUnsubscribeAccess: FeatureAccess.UNLOCKED,
    aiAutomationAccess: FeatureAccess.UNLOCKED,
    coldEmailBlockerAccess: FeatureAccess.UNLOCKED,
  };
}
EOL
```

### Step 5: Modify `utils/premium/check-and-redirect-for-upgrade.tsx`

This file handles redirecting users to the upgrade page.

```bash
cat > apps/web/utils/premium/check-and-redirect-for-upgrade.tsx << 'EOL'
import { redirect } from "next/navigation";
import { isPremium } from "@/utils/premium";
import { auth } from "@/app/api/auth/[...nextauth]/auth";
import prisma from "@/utils/prisma";
import { env } from "@/env";

// PATCHED for local development - Disable upgrade redirects
export async function checkAndRedirectForUpgrade() {
  // Disabled for local development - never redirect to upgrade page
  return;

  // Original code preserved as comments for reference
  /*
  if (!env.NEXT_PUBLIC_WELCOME_UPGRADE_ENABLED) return;

  const session = await auth();

  const email = session?.user.email;

  if (!email) redirect("/login");

  const user = await prisma.user.findUnique({
    where: { email },
    select: {
      premium: { select: { lemonSqueezyRenewsAt: true } },
      completedAppOnboardingAt: true,
    },
  });

  if (!user) redirect("/login");

  if (!isPremium(user.premium?.lemonSqueezyRenewsAt || null)) {
    if (!user.completedAppOnboardingAt) redirect("/onboarding");
    else redirect("/welcome-upgrade");
  }
  */
}
EOL
```

### Step 6: Modify `app/(app)/premium/PremiumModal.tsx`

This file contains the premium upgrade modal.

```bash
cat > apps/web/app/\(app\)/premium/PremiumModal.tsx << 'EOL'
import { useCallback, useState } from "react";
import { Dialog, DialogContent } from "@/components/ui/dialog";
import { Pricing } from "@/app/(app)/premium/Pricing";

// PATCHED for local development - Disable premium modal
export function usePremiumModal() {
  const [isOpen, setIsOpen] = useState(false);

  // Modified to do nothing
  const openModal = () => {
    console.log("Premium modal disabled for local development");
    // Do not open modal by not calling setIsOpen(true)
  };

  const PremiumModal = useCallback(() => {
    // Just return null - never show the premium modal
    return null;
  }, [isOpen]);

  return {
    openModal,
    PremiumModal,
  };
}
EOL
```

### Step 7: Modify Default Plan in Prisma Schema

In order to automatically set new users to the PRO plan in the database, we need to update the Prisma schema:

1. First, examine the current schema:

```bash
cat apps/web/prisma/schema.prisma
```

2. Create a database migration to set the default tier to PRO:

```bash
cd apps/web
npx prisma migrate dev --name "set-default-tier-to-pro"
```

When the Prisma migration prompt appears, enter the following SQL:

```sql
-- Add default PRO tier to all existing and future Premium records
ALTER TABLE "Premium" ALTER COLUMN "tier" SET DEFAULT 'BUSINESS_ANNUALLY';
```

3. Apply the migration:

```bash
npx prisma migrate deploy
```

### Step 8: Create Toggle Plan Mode Script

This script allows toggling between free and premium mode for testing:

```bash
cat > toggle-plan-mode.sh << 'EOL'
#!/bin/bash
# toggle-plan-mode.sh - Switch between free and premium modes for local development

echo "🔄 Toggling premium plan mode..."

# Check if we're currently in premium mode
if [ -f patching/PREMIUM_MODE_ENABLED ]; then
  echo "🔽 Switching to FREE mode..."

  # Restore original files from backup
  cp patching/backup/apps/web/utils/premium/index.ts apps/web/utils/premium/index.ts
  cp patching/backup/apps/web/utils/premium/server.ts apps/web/utils/premium/server.ts
  cp patching/backup/apps/web/utils/premium/check-and-redirect-for-upgrade.tsx apps/web/utils/premium/check-and-redirect-for-upgrade.tsx
  cp patching/backup/apps/web/app/\(app\)/premium/PremiumModal.tsx apps/web/app/\(app\)/premium/PremiumModal.tsx

  # Remove flag file
  rm patching/PREMIUM_MODE_ENABLED

  echo "✅ Now in FREE mode. Restart your Next.js server to see changes."
else
  echo "🔼 Switching to PREMIUM mode..."

  # Run the premium patching script
  bash patching/modify-premium-checks.sh

  # Create flag file
  touch patching/PREMIUM_MODE_ENABLED

  echo "✅ Now in PREMIUM mode. Restart your Next.js server to see changes."
fi
EOL

chmod +x toggle-plan-mode.sh
```

### Step 9: Create Check Plan Default Script

This script checks and displays the current plan default settings:

```bash
cat > check-plan-default.sh << 'EOL'
#!/bin/bash
# check-plan-default.sh - Verify the current plan default settings

echo "🔍 Checking plan default settings..."

# Check patch status
if [ -f patching/PREMIUM_MODE_ENABLED ]; then
  echo "🔹 Premium Mode: ENABLED"
  echo "🔹 All premium features are available for local development."
else
  echo "🔹 Premium Mode: DISABLED"
  echo "🔹 Standard free tier restrictions are in effect."
fi

# Check the modified files
echo ""
echo "🔹 File Status:"

# Check premium utility files
if cmp -s apps/web/utils/premium/index.ts patching/backup/apps/web/utils/premium/index.ts; then
  echo "  - utils/premium/index.ts: ORIGINAL"
else
  echo "  - utils/premium/index.ts: PATCHED"
fi

if cmp -s apps/web/utils/premium/server.ts patching/backup/apps/web/utils/premium/server.ts; then
  echo "  - utils/premium/server.ts: ORIGINAL"
else
  echo "  - utils/premium/server.ts: PATCHED"
fi

if cmp -s apps/web/utils/premium/check-and-redirect-for-upgrade.tsx patching/backup/apps/web/utils/premium/check-and-redirect-for-upgrade.tsx; then
  echo "  - utils/premium/check-and-redirect-for-upgrade.tsx: ORIGINAL"
else
  echo "  - utils/premium/check-and-redirect-for-upgrade.tsx: PATCHED"
fi

if cmp -s apps/web/app/\(app\)/premium/PremiumModal.tsx patching/backup/apps/web/app/\(app\)/premium/PremiumModal.tsx; then
  echo "  - app/(app)/premium/PremiumModal.tsx: ORIGINAL"
else
  echo "  - app/(app)/premium/PremiumModal.tsx: PATCHED"
fi

# Check default Premium tier in database
echo ""
echo "🔹 Database Default Settings:"
cd apps/web
DEFAULT_TIER=$(npx prisma db execute --stdin <<< "SELECT column_default FROM information_schema.columns WHERE table_name='Premium' AND column_name='tier';" --json | grep -o '"tier":"[^"]*"' | cut -d'"' -f4)
cd ../..

if [ -n "$DEFAULT_TIER" ]; then
  echo "  - Default Premium Tier: $DEFAULT_TIER"
else
  echo "  - Default Premium Tier: None set"
fi

echo ""
echo "✅ Plan default check complete."
EOL

chmod +x check-plan-default.sh
```

### Step 10: Create Reset DB and Migrate Script

This script resets the database and runs migrations:

```bash
cat > reset-db-and-migrate.sh << 'EOL'
#!/bin/bash
# reset-db-and-migrate.sh - Reset the database and run migrations

echo "🔄 Preparing to reset database and run migrations..."

# Check if user wants to continue
read -p "⚠️ This will DELETE ALL DATA in your local database. Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "❌ Operation cancelled."
    exit 1
fi

# Check if Docker is running
if ! docker ps &>/dev/null; then
  echo "❌ Error: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

# Check if the database container is running
if ! docker ps | grep -q "inbox-zero-postgres"; then
  echo "❌ Error: Postgres container not found. Starting services..."
  docker-compose up -d
  # Wait for services to start
  sleep 5
fi

echo "🔽 Dropping existing database..."
docker exec inbox-zero-postgres-1 psql -U inbox -c "DROP DATABASE IF EXISTS inboxdb WITH (FORCE);"

echo "🔼 Creating new database..."
docker exec inbox-zero-postgres-1 psql -U inbox -c "CREATE DATABASE inboxdb;"

echo "🔄 Generating Prisma client..."
cd apps/web
npx prisma generate

echo "🔄 Running migrations..."
npx prisma migrate deploy

echo "🔄 Seeding default data..."
npx prisma db seed

cd ../..

echo "✅ Database reset and migrations complete!"
echo "   You can now start the application with: ./start-local.sh"
EOL

chmod +x reset-db-and-migrate.sh
```

### Step 11: Create Dev Bootstrap Script

This script sets up the entire development environment:

```bash
cat > dev-bootstrap.sh << 'EOL'
#!/bin/bash
# dev-bootstrap.sh - Bootstrap the development environment

echo "🔧 Setting up Inbox Zero development environment..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
  echo "❌ Error: Docker not found. Please install Docker Desktop first."
  exit 1
fi

# Check if Docker is running
if ! docker ps &>/dev/null; then
  echo "❌ Error: Docker is not running. Please start Docker Desktop and try again."
  exit 1
fi

# 1. Install dependencies
echo "📦 Installing dependencies..."
pnpm install

# 2. Create .env.local if it doesn't exist
if [ ! -f .env.local ]; then
  echo "📝 Creating .env.local from template..."
  cp .env.example .env.local

  # Generate random secrets
  NEXTAUTH_SECRET=$(openssl rand -base64 32)
  JWT_SECRET=$(openssl rand -base64 32)
  API_KEY_SALT=$(openssl rand -base64 32)

  # Update secrets in .env.local
  sed -i '' "s/NEXTAUTH_SECRET=.*/NEXTAUTH_SECRET=$NEXTAUTH_SECRET/" .env.local
  sed -i '' "s/JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" .env.local
  sed -i '' "s/API_KEY_SALT=.*/API_KEY_SALT=$API_KEY_SALT/" .env.local

  echo "  - Generated secure random secrets in .env.local"
fi

# 3. Create apps/web/.env.local if it doesn't exist
if [ ! -f apps/web/.env.local ]; then
  echo "📝 Creating apps/web/.env.local from template..."
  cp apps/web/.env.example apps/web/.env.local

  # Copy values from root .env.local
  cat .env.local > apps/web/.env.local

  echo "  - Copied environment variables to apps/web/.env.local"
fi

# 4. Start database containers
echo "🐳 Starting database containers..."
docker-compose up -d

# 5. Wait for databases to be ready
echo "⏳ Waiting for databases to be ready..."
sleep 5

# 6. Initialize database
echo "🗃️ Setting up database..."
./reset-db-and-migrate.sh

# 7. Apply premium patches
echo "⚡ Applying premium patches for local development..."
./toggle-plan-mode.sh

# 8. Start the application
echo "🚀 Starting Inbox Zero application..."
./start-local.sh
EOL

chmod +x dev-bootstrap.sh
```

### Step 12: Create Backup Postgres Script

This script creates database backups:

```bash
cat > backup-postgres.sh << 'EOL'
#!/bin/bash
# backup-postgres.sh - Create a backup of the Postgres database

# Create backups directory if it doesn't exist
mkdir -p db-backups

# Generate timestamp for the backup filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="db-backups/inboxdb_backup_$TIMESTAMP.sql"

echo "📦 Creating database backup to $BACKUP_FILE..."

# Run pg_dump inside the container to create the backup
docker exec inbox-zero-postgres-1 pg_dump -U inbox -d inboxdb -f /tmp/backup.sql

# Copy the backup file from the container
docker cp inbox-zero-postgres-1:/tmp/backup.sql "$BACKUP_FILE"

# Remove the temporary file in the container
docker exec inbox-zero-postgres-1 rm /tmp/backup.sql

# Check if backup was successful
if [ -f "$BACKUP_FILE" ]; then
  # Get the file size
  BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  echo "✅ Backup completed successfully! Size: $BACKUP_SIZE"
  echo "   Backup saved to: $BACKUP_FILE"
else
  echo "❌ Backup failed. Please check for errors."
fi
EOL

chmod +x backup-postgres.sh
```

### Step 13: Verify Local Settings

After applying all the patches and creating the utility scripts, verify that everything is set up correctly:

1. Check that all script files have executable permissions:

```bash
ls -la *.sh
```

2. Run the check-plan-default.sh script to verify the current settings:

```bash
./check-plan-default.sh
```

3. Restart the Next.js server to apply the changes:

```bash
# First, stop any running server
pkill -f "npm run dev"
# Then start the server
./start-local.sh
```

### Step 14: Test Premium Features

After restarting the server, test that all premium features are properly enabled:

1. **Login and Authentication**:

   - Sign in with Google
   - Verify no upgrade modals appear

2. **Premium Features Testing**:

   - Test bulk unsubscribe functionality
   - Test AI automation features
   - Verify cold email blocker works
   - Check that sender categories function properly

3. **Plan Status Check**:
   - Verify user has PRO plan status in the UI
   - Confirm no upgrade buttons appear throughout the interface

## Troubleshooting Common Issues

### Issue: Premium modal still appears

**Solution**: Make sure you've properly modified `PremiumModal.tsx` and restarted the Next.js server.

```bash
cat apps/web/app/\(app\)/premium/PremiumModal.tsx
./toggle-plan-mode.sh  # To reapply the patch
# Restart the server
```

### Issue: Features still restricted

**Solution**: Check if the database records have the correct premium tier:

```bash
cd apps/web
npx prisma studio
# Look for your user record and check its premium relationship
# Verify the premium record has the correct tier and feature access flags
```

### Issue: Database migration fails

**Solution**: Reset the database and try again:

```bash
./reset-db-and-migrate.sh
```

### Issue: Environment variables not applied

**Solution**: Make sure both `.env.local` files contain the correct values:

```bash
cat .env.local
cat apps/web/.env.local
```

## Summary of Files Modified

1. `apps/web/utils/premium/index.ts`: Client-side premium checks
2. `apps/web/utils/premium/server.ts`: Server-side premium checks
3. `apps/web/utils/premium/check-and-redirect-for-upgrade.tsx`: Upgrade redirects
4. `apps/web/app/(app)/premium/PremiumModal.tsx`: Premium modal UI
5. `apps/web/prisma/schema.prisma`: Database schema (via migration)

## Summary of Scripts Created

1. `toggle-plan-mode.sh`: Switch between free/paid mode
2. `check-plan-default.sh`: Verify current plan settings
3. `reset-db-and-migrate.sh`: Reset database and run migrations
4. `dev-bootstrap.sh`: Set up development environment
5. `backup-postgres.sh`: Create database backups

This comprehensive approach ensures that all premium features are enabled for local development, with no upgrade modals or limitations, while providing the ability to toggle back to free mode for testing as needed.
