# Comprehensive Guide: Implementing Local Subscription System for Inbox Zero

This guide provides detailed instructions for implementing a local subscription system for Inbox Zero that preserves the original subscription architecture while enabling you to grant premium access in your local development environment.

## Table of Contents

1. [Introduction and Overview](#introduction-and-overview)
2. [Prerequisites](#prerequisites)
3. [Understanding the Subscription Architecture](#understanding-the-subscription-architecture)
4. [Implementation Steps](#implementation-steps)
   - [Step 1: Setting Up Environment Variables](#step-1-setting-up-environment-variables)
   - [Step 2: Creating a Development Admin API](#step-2-creating-a-development-admin-api)
   - [Step 3: Building a Subscription Management UI](#step-3-building-a-subscription-management-ui)
   - [Step 4: Database Schema Modifications](#step-4-database-schema-modifications)
   - [Step 5: Creating Utility Scripts](#step-5-creating-utility-scripts)
5. [Testing the Implementation](#testing-the-implementation)
6. [Troubleshooting Common Issues](#troubleshooting-common-issues)
7. [Appendix: Lemon Squeezy Integration (Optional)](#appendix-lemon-squeezy-integration-optional)

## Introduction and Overview

Inbox Zero uses a subscription-based model with Lemon Squeezy as its payment processor. Instead of bypassing the subscription system entirely, this approach maintains the original architecture while adding development-only endpoints to grant premium access locally.

**Benefits of this approach:**

- Preserves the subscription architecture for future commercialization
- Allows testing different premium tiers and features
- Provides a smoother transition path if you want to launch commercially later
- Avoids having to undo patches when you want to restore subscription functionality

## Prerequisites

Before beginning the implementation, ensure you have:

- A local development environment for Inbox Zero
- Node.js v22.0.0 or higher
- Docker Desktop installed and running
- Basic understanding of Next.js and TypeScript
- Access to the terminal/command line

## Understanding the Subscription Architecture

Inbox Zero's subscription system consists of:

1. **Payment Processing**:

   - Lemon Squeezy integration for handling payments
   - Webhook endpoints for processing subscription events
   - API routes for managing subscriptions

2. **Database Models**:

   - `Premium` model stores subscription details
   - `User` model links to premium status via `premiumId`
   - Relationship between users and premium subscriptions (one premium can have multiple users)

3. **Feature Access Control**:

   - Utility functions check subscription status
   - Feature flags in the Premium model control access to specific features
   - Different tiers (BASIC, PRO, BUSINESS, etc.) provide different feature sets

4. **Subscription Flow**:
   - User initiates subscription purchase
   - Lemon Squeezy processes payment
   - Webhook receives event and updates database
   - User gains access to premium features

Our implementation will create a development-only shortcut to grant premium access, bypassing the payment but using the same database structures and access control mechanisms.

## Implementation Steps

### Step 1: Setting Up Environment Variables

First, we need to ensure our environment is properly configured:

1. **Create or update `.env.local` with development variables**:

```bash
# Create or edit the root .env.local file
cat > .env.local << 'EOL'
# Add these to your existing .env.local file

# Database configuration
DATABASE_URL=postgresql://inbox:inboxpassword@localhost:5432/inboxdb
DIRECT_URL=postgresql://inbox:inboxpassword@localhost:5432/inboxdb

# Development mode flag
NODE_ENV=development
NEXT_PUBLIC_DEV_MODE=true

# Lemon Squeezy (dummy values for dev)
LEMON_SQUEEZY_API_KEY=dummy_key
LEMON_SQUEEZY_STORE_ID=dummy_store
LEMON_SQUEEZY_WEBHOOK_SECRET=dummy_secret

# Premium Plan IDs (these can be dummy values)
PREMIUM_BASIC_MONTHLY_VARIANT_ID=123456
PREMIUM_BASIC_ANNUALLY_VARIANT_ID=123457
PREMIUM_PRO_MONTHLY_VARIANT_ID=123458
PREMIUM_PRO_ANNUALLY_VARIANT_ID=123459
PREMIUM_BUSINESS_MONTHLY_VARIANT_ID=123460
PREMIUM_BUSINESS_ANNUALLY_VARIANT_ID=123461
EOL

# Copy to the web app .env.local
cp .env.local apps/web/.env.local
```

2. **Update your `apps/web/env.ts` file to include development flags**:

Ensure the `env.ts` file includes the development mode flag by checking it exists or adding it if needed:

```bash
grep -q "NEXT_PUBLIC_DEV_MODE" apps/web/env.ts || echo "Need to add NEXT_PUBLIC_DEV_MODE to env.ts"
```

If needed, add the development flag to `env.ts`:

```typescript
// Add this to apps/web/env.ts in the appropriate section
NEXT_PUBLIC_DEV_MODE: z.boolean().optional().default(false),
```

### Step 2: Creating a Development Admin API

Now we'll create a development-only API to manage subscriptions:

1. **Create the API directory structure**:

```bash
mkdir -p apps/web/app/api/dev/subscription
```

2. **Create the grant premium endpoint**:

```bash
cat > apps/web/app/api/dev/subscription/route.ts << 'EOL'
import { NextRequest, NextResponse } from "next/server";
import { env } from "@/env";
import { PremiumTier, FeatureAccess } from "@prisma/client";
import prisma from "@/utils/prisma";
import { auth } from "@/app/api/auth/[...nextauth]/auth";
import { createScopedLogger } from "@/utils/logger";

const logger = createScopedLogger("dev-subscription");

// Block access in production
const isDevelopment = env.NODE_ENV === "development" || process.env.NODE_ENV === "development";

// Helper function to validate subscription tiers
function isValidTier(tier: string): tier is PremiumTier {
  return Object.values(PremiumTier).includes(tier as PremiumTier);
}

// This generates a new premium subscription for the user
export async function POST(req: NextRequest) {
  // Only available in development
  if (!isDevelopment) {
    return NextResponse.json(
      { error: "This endpoint is only available in development mode" },
      { status: 403 }
    );
  }

  try {
    // Get current user from session
    const session = await auth();
    if (!session?.user?.email) {
      return NextResponse.json(
        { error: "Authentication required" },
        { status: 401 }
      );
    }

    // Parse request body
    const body = await req.json();
    const {
      tier = PremiumTier.BUSINESS_ANNUALLY,
      durationMonths = 12
    } = body;

    // Validate tier
    if (!isValidTier(tier)) {
      return NextResponse.json(
        { error: "Invalid premium tier" },
        { status: 400 }
      );
    }

    // Calculate expiration date
    const expiresAt = new Date();
    expiresAt.setMonth(expiresAt.getMonth() + durationMonths);

    // Get current user
    const user = await prisma.user.findUnique({
      where: { email: session.user.email },
      select: { id: true, premiumId: true }
    });

    if (!user) {
      return NextResponse.json(
        { error: "User not found" },
        { status: 404 }
      );
    }

    // Determine feature access based on tier
    let featureAccess = {
      bulkUnsubscribeAccess: FeatureAccess.UNLOCKED,
      aiAutomationAccess: FeatureAccess.LOCKED,
      coldEmailBlockerAccess: FeatureAccess.LOCKED,
      emailAccountsAccess: 1,
    };

    switch(tier) {
      case PremiumTier.PRO_MONTHLY:
      case PremiumTier.PRO_ANNUALLY:
        featureAccess.aiAutomationAccess = FeatureAccess.UNLOCKED_WITH_API_KEY;
        featureAccess.coldEmailBlockerAccess = FeatureAccess.UNLOCKED_WITH_API_KEY;
        featureAccess.emailAccountsAccess = 3;
        break;

      case PremiumTier.BUSINESS_MONTHLY:
      case PremiumTier.BUSINESS_ANNUALLY:
      case PremiumTier.LIFETIME:
        featureAccess.aiAutomationAccess = FeatureAccess.UNLOCKED;
        featureAccess.coldEmailBlockerAccess = FeatureAccess.UNLOCKED;
        featureAccess.emailAccountsAccess = 10;
        break;
    }

    // Create or update premium subscription
    let premium;
    if (user.premiumId) {
      // Update existing premium subscription
      premium = await prisma.premium.update({
        where: { id: user.premiumId },
        data: {
          tier,
          lemonSqueezyRenewsAt: expiresAt,
          lemonSqueezyCustomerId: 123456789, // Dummy ID for development
          lemonSqueezySubscriptionId: 987654321, // Dummy ID for development
          lemonSqueezySubscriptionItemId: 555555555, // Dummy ID for development
          ...featureAccess
        },
        include: {
          users: {
            select: { email: true }
          }
        }
      });
    } else {
      // Create new premium subscription
      premium = await prisma.premium.create({
        data: {
          tier,
          lemonSqueezyRenewsAt: expiresAt,
          lemonSqueezyCustomerId: 123456789, // Dummy ID for development
          lemonSqueezySubscriptionId: 987654321, // Dummy ID for development
          lemonSqueezySubscriptionItemId: 555555555, // Dummy ID for development
          ...featureAccess,
          users: { connect: { id: user.id } },
          admins: { connect: { id: user.id } }
        },
        include: {
          users: {
            select: { email: true }
          }
        }
      });
    }

    logger.info(`Development premium subscription created/updated`, {
      email: session.user.email,
      tier,
      expiresAt
    });

    return NextResponse.json({
      success: true,
      message: `Premium subscription ${user.premiumId ? 'updated' : 'created'}`,
      premium: {
        tier,
        expiresAt,
        ...featureAccess
      }
    });
  } catch (error) {
    logger.error("Error creating development premium subscription", { error });
    return NextResponse.json(
      { error: "Failed to create premium subscription" },
      { status: 500 }
    );
  }
}

// This cancels the user's premium subscription
export async function DELETE(req: NextRequest) {
  // Only available in development
  if (!isDevelopment) {
    return NextResponse.json(
      { error: "This endpoint is only available in development mode" },
      { status: 403 }
    );
  }

  try {
    // Get current user from session
    const session = await auth();
    if (!session?.user?.email) {
      return NextResponse.json(
        { error: "Authentication required" },
        { status: 401 }
      );
    }

    // Get current user
    const user = await prisma.user.findUnique({
      where: { email: session.user.email },
      select: { id: true, premiumId: true }
    });

    if (!user || !user.premiumId) {
      return NextResponse.json(
        { error: "No premium subscription found" },
        { status: 404 }
      );
    }

    // Set subscription to expired (yesterday)
    const expiredDate = new Date();
    expiredDate.setDate(expiredDate.getDate() - 1);

    // Update premium subscription to be expired
    await prisma.premium.update({
      where: { id: user.premiumId },
      data: {
        lemonSqueezyRenewsAt: expiredDate,
        bulkUnsubscribeAccess: FeatureAccess.LOCKED,
        aiAutomationAccess: FeatureAccess.LOCKED,
        coldEmailBlockerAccess: FeatureAccess.LOCKED,
      }
    });

    logger.info(`Development premium subscription canceled`, {
      email: session.user.email
    });

    return NextResponse.json({
      success: true,
      message: "Premium subscription canceled"
    });
  } catch (error) {
    logger.error("Error canceling development premium subscription", { error });
    return NextResponse.json(
      { error: "Failed to cancel premium subscription" },
      { status: 500 }
    );
  }
}

// This gets the user's current subscription info
export async function GET(req: NextRequest) {
  // Only available in development
  if (!isDevelopment) {
    return NextResponse.json(
      { error: "This endpoint is only available in development mode" },
      { status: 403 }
    );
  }

  try {
    // Get current user from session
    const session = await auth();
    if (!session?.user?.email) {
      return NextResponse.json(
        { error: "Authentication required" },
        { status: 401 }
      );
    }

    // Get current user with premium info
    const user = await prisma.user.findUnique({
      where: { email: session.user.email },
      select: {
        id: true,
        premiumId: true,
        premium: {
          select: {
            tier: true,
            lemonSqueezyRenewsAt: true,
            bulkUnsubscribeAccess: true,
            aiAutomationAccess: true,
            coldEmailBlockerAccess: true,
            emailAccountsAccess: true
          }
        }
      }
    });

    if (!user) {
      return NextResponse.json(
        { error: "User not found" },
        { status: 404 }
      );
    }

    // Check if premium is active
    const isPremiumActive = user.premium?.lemonSqueezyRenewsAt
      ? new Date(user.premium.lemonSqueezyRenewsAt) > new Date()
      : false;

    return NextResponse.json({
      premiumActive: isPremiumActive,
      premium: user.premium ? {
        ...user.premium,
        active: isPremiumActive
      } : null
    });
  } catch (error) {
    logger.error("Error fetching development premium subscription", { error });
    return NextResponse.json(
      { error: "Failed to fetch premium subscription" },
      { status: 500 }
    );
  }
}
EOL
```

### Step 3: Building a Subscription Management UI

Now we'll create a simple UI to manage subscriptions in development:

1. **Create the UI directory structure**:

```bash
mkdir -p apps/web/app/(app)/dev/subscription
```

2. **Create the subscription management page**:

```bash
cat > apps/web/app/\(app\)/dev/subscription/page.tsx << 'EOL'
"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { PremiumTier, FeatureAccess } from "@prisma/client";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { env } from "@/env";

// Only allow access in development mode
const isDevelopment = typeof window !== "undefined" &&
  (window.location.hostname === "localhost" ||
   window.location.hostname === "127.0.0.1");

export default function SubscriptionManager() {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);
  const [tier, setTier] = useState<PremiumTier>(PremiumTier.BUSINESS_ANNUALLY);
  const [durationMonths, setDurationMonths] = useState(12);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [subscriptionInfo, setSubscriptionInfo] = useState<any>(null);
  const [isRefreshing, setIsRefreshing] = useState(true);

  // Redirect if not in development mode
  useEffect(() => {
    if (!isDevelopment) {
      router.push("/");
    }
  }, [router]);

  // Fetch current subscription info
  const fetchSubscriptionInfo = async () => {
    try {
      setIsRefreshing(true);
      const response = await fetch("/api/dev/subscription");
      const data = await response.json();

      if (response.ok) {
        setSubscriptionInfo(data);
      } else {
        console.error("Failed to fetch subscription info:", data.error);
      }
    } catch (error) {
      console.error("Error fetching subscription info:", error);
    } finally {
      setIsRefreshing(false);
    }
  };

  // Load subscription info on mount
  useEffect(() => {
    fetchSubscriptionInfo();
  }, []);

  // Handle creating/updating subscription
  const handleCreateSubscription = async () => {
    setIsLoading(true);
    setError(null);
    setSuccess(null);

    try {
      const response = await fetch("/api/dev/subscription", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          tier,
          durationMonths
        }),
      });

      const data = await response.json();

      if (response.ok) {
        setSuccess(data.message);
        fetchSubscriptionInfo();
      } else {
        setError(data.error || "Failed to create subscription");
      }
    } catch (error) {
      setError("An unexpected error occurred");
      console.error(error);
    } finally {
      setIsLoading(false);
    }
  };

  // Handle cancelling subscription
  const handleCancelSubscription = async () => {
    if (!confirm("Are you sure you want to cancel this subscription?")) {
      return;
    }

    setIsLoading(true);
    setError(null);
    setSuccess(null);

    try {
      const response = await fetch("/api/dev/subscription", {
        method: "DELETE",
      });

      const data = await response.json();

      if (response.ok) {
        setSuccess(data.message);
        fetchSubscriptionInfo();
      } else {
        setError(data.error || "Failed to cancel subscription");
      }
    } catch (error) {
      setError("An unexpected error occurred");
      console.error(error);
    } finally {
      setIsLoading(false);
    }
  };

  // Handle refresh button
  const handleRefresh = () => {
    fetchSubscriptionInfo();
  };

  if (!isDevelopment) {
    return null;
  }

  return (
    <div className="container mx-auto py-10 max-w-4xl">
      <h1 className="text-3xl font-bold mb-2">Development Subscription Manager</h1>
      <p className="text-gray-500 mb-8">Create and manage premium subscriptions for local development</p>

      {error && (
        <Alert variant="destructive" className="mb-6">
          <AlertTitle>Error</AlertTitle>
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {success && (
        <Alert className="mb-6 bg-green-50 border-green-200">
          <AlertTitle>Success</AlertTitle>
          <AlertDescription>{success}</AlertDescription>
        </Alert>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <Card>
          <CardHeader>
            <CardTitle>Create/Update Subscription</CardTitle>
            <CardDescription>Grant premium features to your account</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="tier">Subscription Tier</Label>
              <Select
                value={tier}
                onValueChange={(value) => setTier(value as PremiumTier)}
              >
                <SelectTrigger id="tier">
                  <SelectValue placeholder="Select a tier" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value={PremiumTier.BASIC_MONTHLY}>Basic (Monthly)</SelectItem>
                  <SelectItem value={PremiumTier.BASIC_ANNUALLY}>Basic (Annually)</SelectItem>
                  <SelectItem value={PremiumTier.PRO_MONTHLY}>Pro (Monthly)</SelectItem>
                  <SelectItem value={PremiumTier.PRO_ANNUALLY}>Pro (Annually)</SelectItem>
                  <SelectItem value={PremiumTier.BUSINESS_MONTHLY}>Business (Monthly)</SelectItem>
                  <SelectItem value={PremiumTier.BUSINESS_ANNUALLY}>Business (Annually)</SelectItem>
                  <SelectItem value={PremiumTier.LIFETIME}>Lifetime</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="duration">Duration (months)</Label>
              <Input
                id="duration"
                type="number"
                value={durationMonths}
                onChange={(e) => setDurationMonths(parseInt(e.target.value))}
                min={1}
                max={120}
              />
              <p className="text-xs text-gray-500">
                {tier === PremiumTier.LIFETIME ?
                  "For Lifetime tier, duration will be set to 10 years regardless of this value" :
                  "How long the subscription should last before expiring"}
              </p>
            </div>
          </CardContent>
          <CardFooter className="flex justify-between">
            <Button
              variant="outline"
              onClick={fetchSubscriptionInfo}
              disabled={isLoading || isRefreshing}
            >
              Refresh
            </Button>
            <Button
              onClick={handleCreateSubscription}
              disabled={isLoading}
            >
              {isLoading ? "Processing..." : subscriptionInfo?.premiumActive ? "Update Subscription" : "Create Subscription"}
            </Button>
          </CardFooter>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Current Subscription</CardTitle>
            <CardDescription>
              Your active subscription details
            </CardDescription>
          </CardHeader>
          <CardContent>
            {isRefreshing ? (
              <div className="text-center py-8">Loading subscription info...</div>
            ) : !subscriptionInfo?.premium ? (
              <div className="text-center py-8 text-gray-500">No active subscription found</div>
            ) : (
              <div className="space-y-4">
                <div className="grid grid-cols-2 gap-2">
                  <div className="font-medium">Status:</div>
                  <div>
                    <span className={`px-2 py-1 rounded-full text-xs ${
                      subscriptionInfo.premiumActive ? "bg-green-100 text-green-800" : "bg-red-100 text-red-800"
                    }`}>
                      {subscriptionInfo.premiumActive ? "Active" : "Inactive"}
                    </span>
                  </div>

                  <div className="font-medium">Tier:</div>
                  <div>{subscriptionInfo.premium.tier}</div>

                  <div className="font-medium">Expires:</div>
                  <div>
                    {subscriptionInfo.premium.lemonSqueezyRenewsAt ?
                      new Date(subscriptionInfo.premium.lemonSqueezyRenewsAt).toLocaleDateString() :
                      "N/A"}
                  </div>

                  <div className="font-medium">Bulk Unsubscribe:</div>
                  <div>{subscriptionInfo.premium.bulkUnsubscribeAccess}</div>

                  <div className="font-medium">AI Automation:</div>
                  <div>{subscriptionInfo.premium.aiAutomationAccess}</div>

                  <div className="font-medium">Cold Email Blocker:</div>
                  <div>{subscriptionInfo.premium.coldEmailBlockerAccess}</div>

                  <div className="font-medium">Email Accounts:</div>
                  <div>{subscriptionInfo.premium.emailAccountsAccess || 1}</div>
                </div>
              </div>
            )}
          </CardContent>
          <CardFooter className="flex justify-between">
            <Button
              variant="outline"
              onClick={handleRefresh}
              disabled={isLoading || isRefreshing}
            >
              Refresh
            </Button>
            <Button
              variant="destructive"
              onClick={handleCancelSubscription}
              disabled={isLoading || !subscriptionInfo?.premiumActive}
            >
              Cancel Subscription
            </Button>
          </CardFooter>
        </Card>
      </div>

      <div className="mt-8 p-4 bg-gray-50 rounded-lg border border-gray-200">
        <h3 className="font-medium mb-2">Development Mode Notes</h3>
        <p className="text-sm text-gray-600 mb-2">
          This interface is only available in development mode and allows you to create/manage premium
          subscriptions without actual payment processing.
        </p>
        <p className="text-sm text-gray-600">
          All subscriptions created here use the same database models and premium checks as the
          production system, but bypass the Lemon Squeezy payment flow.
        </p>
      </div>
    </div>
  );
}
EOL
```

3. **Create a layout file to ensure the UI has the proper structure**:

```bash
cat > apps/web/app/\(app\)/dev/subscription/layout.tsx << 'EOL'
import { ReactNode } from "react";

export default function SubscriptionLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <div className="min-h-screen bg-gray-50">
      {children}
    </div>
  );
}
EOL
```

### Step 4: Database Schema Modifications

Now, we'll make a minor change to ensure that new Premium records have the correct feature access by default:

1. **Create a new Prisma migration**:

```bash
cd apps/web
npx prisma migrate dev --name add_default_feature_access
```

2. When prompted for migration content, enter the following SQL:

```sql
-- Set default values for feature access flags
ALTER TABLE "Premium" ALTER COLUMN "bulkUnsubscribeAccess" SET DEFAULT 'UNLOCKED';
ALTER TABLE "Premium" ALTER COLUMN "aiAutomationAccess" SET DEFAULT 'UNLOCKED';
ALTER TABLE "Premium" ALTER COLUMN "coldEmailBlockerAccess" SET DEFAULT 'UNLOCKED';
ALTER TABLE "Premium" ALTER COLUMN "emailAccountsAccess" SET DEFAULT 10;
```

3. **Apply the migration**:

```bash
npx prisma migrate deploy
cd ../..
```

### Step 5: Creating Utility Scripts

Let's create some utility scripts to manage the local subscription system:

1. **Create a script to open the subscription manager**:

```bash
cat > open-subscription-manager.sh << 'EOL'
#!/bin/bash
# open-subscription-manager.sh - Open the development subscription manager

echo "🔍 Opening Development Subscription Manager..."

# Check if the server is running
if ! curl -s http://localhost:3000 > /dev/null; then
  echo "⚠️ Local server doesn't appear to be running."
  echo "   Starting the server first..."
  ./start-local.sh &

  # Wait for server to start
  echo "⏳ Waiting for server to start..."
  for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null; then
      echo "✅ Server is now running!"
      break
    fi
    sleep 1
    if [ $i -eq 30 ]; then
      echo "❌ Server failed to start in time. Please run './start-local.sh' manually."
      exit 1
    fi
  done
fi

# Open the subscription manager in the default browser
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  open http://localhost:3000/dev/subscription
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux
  xdg-open http://localhost:3000/dev/subscription
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  # Windows
  start http://localhost:3000/dev/subscription
else
  echo "⚠️ Could not automatically open browser."
  echo "   Please open this URL manually: http://localhost:3000/dev/subscription"
fi

echo "✅ Subscription Manager opened in your browser!"
echo "   You can use it to create or manage your development premium subscription."
EOL

chmod +x open-subscription-manager.sh
```

2. **Create a script to check subscription status**:

```bash
cat > check-subscription-status.sh << 'EOL'
#!/bin/bash
# check-subscription-status.sh - Check the current subscription status

echo "🔍 Checking subscription status..."

# Check if the server is running
if ! curl -s http://localhost:3000 > /dev/null; then
  echo "❌ Error: Local server is not running. Please start it with './start-local.sh'"
  exit 1
fi

# Make API request to get subscription info
RESPONSE=$(curl -s -X GET http://localhost:3000/api/dev/subscription)

# Check if we got a valid response
if [[ $RESPONSE == *"error"* ]]; then
  ERROR=$(echo $RESPONSE | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
  echo "❌ Error: $ERROR"
  if [[ $ERROR == *"Authentication required"* ]]; then
    echo "   Please make sure you're logged in to Inbox Zero."
  fi
  exit 1
fi

# Parse and display the subscription info
PREMIUM_ACTIVE=$(echo $RESPONSE | grep -o '"premiumActive":\s*\w\+' | cut -d: -f2 | tr -d ' ')

echo "🔹 Subscription Status:"
if [[ $PREMIUM_ACTIVE == "true" ]]; then
  echo "   ✅ Premium subscription is ACTIVE"

  # Extract and display tier
  TIER=$(echo $RESPONSE | grep -o '"tier":"[^"]*"' | cut -d'"' -f4)
  echo "   🔹 Tier: $TIER"

  # Extract and display expiration date
  EXPIRES_AT=$(echo $RESPONSE | grep -o '"lemonSqueezy
```
