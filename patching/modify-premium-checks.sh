#!/bin/bash
# This script patches the premium-check functionality in Inbox Zero to always allow full access
# Following the steps outlined in the PRD to remove free tier limits

echo "🔧 Starting to patch Inbox Zero premium restrictions..."

# Create directories if they don't exist
mkdir -p patching/backup

# Function to backup a file before modifying it
backup_file() {
    local file_path=$1
    local backup_dir="patching/backup"
    local filename=$(basename "$file_path")
    local dir_path=$(dirname "$file_path")
    local rel_path=${dir_path#/Users/welovekiteboarding/Development/inbox-zero/}
    
    mkdir -p "$backup_dir/$rel_path"
    cp "$file_path" "$backup_dir/$rel_path/$filename"
    echo "✅ Backed up $file_path to $backup_dir/$rel_path/$filename"
}

# 1. Modify premium check in index.ts
PREMIUM_FILE="apps/web/utils/premium/index.ts"
if [ -f "$PREMIUM_FILE" ]; then
    echo "📝 Modifying premium checks in $PREMIUM_FILE..."
    backup_file "$PREMIUM_FILE"
    
    # Replace premium checking functions with ones that always return true
    cat > "$PREMIUM_FILE" << 'EOL'
// apps/web/utils/premium/index.ts - PATCHED for local use
// Modified to always return true for premium features

export const premiumEnabled = () => true;
export const isPremium = () => true;
export const isPremiumWithSeats = () => true;
export const isPremiumLifetime = () => true;
export const isAdmin = () => true;
export const getPlanType = () => "PRO";
export const getNumberOfSeats = () => 999;
export const getRemainingSeats = () => 999;
EOL
    echo "✅ Modified $PREMIUM_FILE to always enable premium features"
fi

# 2. Modify premium check server functions
PREMIUM_SERVER_FILE="apps/web/utils/premium/server.ts"
if [ -f "$PREMIUM_SERVER_FILE" ]; then
    echo "📝 Modifying server-side premium checks in $PREMIUM_SERVER_FILE..."
    backup_file "$PREMIUM_SERVER_FILE"
    
    # Replace server-side premium checking functions
    cat > "$PREMIUM_SERVER_FILE" << 'EOL'
// apps/web/utils/premium/server.ts - PATCHED for local use
// Modified to always return premium access on server side

export const getUserPremium = async () => {
  return {
    premium: true,
    renewsAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 365 * 5), // 5 years from now
    planId: "pro_unlimited",
    subscriptionId: "local_unlimited",
    subscriptionItemId: "local_item",
    seats: 999,
    usedSeats: 0,
    admin: true,
  };
};

export const getUserPremiumById = async () => {
  return {
    premium: true,
    renewsAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 365 * 5), // 5 years from now
    planId: "pro_unlimited",
    subscriptionId: "local_unlimited",
    subscriptionItemId: "local_item",
    seats: 999,
    usedSeats: 0,
    admin: true,
  };
};

export const getPremiumForCurrentUser = async () => {
  return {
    premium: true,
    renewsAt: new Date(Date.now() + 1000 * 60 * 60 * 24 * 365 * 5), // 5 years from now
    planId: "pro_unlimited",
    subscriptionId: "local_unlimited",
    subscriptionItemId: "local_item",
    seats: 999,
    usedSeats: 0,
    admin: true,
  };
};
EOL
    echo "✅ Modified $PREMIUM_SERVER_FILE to always return premium status for users"
fi

# 3. Modify redirect for upgrade check
UPGRADE_CHECK_FILE="apps/web/utils/premium/check-and-redirect-for-upgrade.tsx"
if [ -f "$UPGRADE_CHECK_FILE" ]; then
    echo "📝 Modifying upgrade check redirect in $UPGRADE_CHECK_FILE..."
    backup_file "$UPGRADE_CHECK_FILE"
    
    # Replace the upgrade redirect to never redirect
    cat > "$UPGRADE_CHECK_FILE" << 'EOL'
// apps/web/utils/premium/check-and-redirect-for-upgrade.tsx - PATCHED for local use
// Modified to never redirect to upgrade page

import { getUserPremium } from "./server";

export default async function checkAndRedirectForUpgrade({
  redirectTo,
}: {
  redirectTo: string;
}) {
  // Always return as premium user, no redirects
  return {
    premium: true,
    redirect: false,
  };
}
EOL
    echo "✅ Modified $UPGRADE_CHECK_FILE to never redirect to upgrade page"
fi

# 4. Modify the premium modal to not show
PREMIUM_MODAL_FILE="apps/web/app/(app)/premium/PremiumModal.tsx"
if [ -f "$PREMIUM_MODAL_FILE" ]; then
    echo "📝 Modifying premium modal in $PREMIUM_MODAL_FILE..."
    backup_file "$PREMIUM_MODAL_FILE"
    
    # Find the component definition line
    modal_component_line=$(grep -n "export function PremiumModal" "$PREMIUM_MODAL_FILE" | cut -d':' -f1)
    
    if [ -n "$modal_component_line" ]; then
        # Get first few lines of the file
        head_content=$(head -n "$modal_component_line" "$PREMIUM_MODAL_FILE")
        
        # Create the new file content
        cat > "$PREMIUM_MODAL_FILE" << EOL
$head_content
  // PATCHED for local use - Premium modal disabled
  
  return null; // Don't show any premium modal
}
EOL
        echo "✅ Modified $PREMIUM_MODAL_FILE to not display premium upgrade modal"
    else
        echo "⚠️ Could not find PremiumModal component in file. Manual check may be needed."
    fi
fi

# 5. Create a README explaining the changes
cat > "patching/README.md" << 'EOL'
# Inbox Zero Premium Patches

This folder contains scripts and backups for patches that remove the premium tier restrictions from Inbox Zero for local use.

## What was patched?

1. `utils/premium/index.ts` - Client-side premium checks now always return true
2. `utils/premium/server.ts` - Server-side premium user checks now always return a premium user
3. `utils/premium/check-and-redirect-for-upgrade.tsx` - Removed redirects to upgrade page
4. `app/(app)/premium/PremiumModal.tsx` - Disabled the premium modal display

## Restoring original files

Backup copies of the original files are stored in the `patching/backup` directory. To restore:

```bash
# Example for restoring a file
cp patching/backup/apps/web/utils/premium/index.ts apps/web/utils/premium/index.ts
```

## License Compliance

These modifications are for personal local development use only, in compliance with the AGPL-3.0 license of the original project.
EOL

echo "✅ Created patching documentation in patching/README.md"

echo "🎉 Patching complete! Inbox Zero should now have all premium features enabled for local use."
echo "   You may need to restart your Next.js server for changes to take effect."
