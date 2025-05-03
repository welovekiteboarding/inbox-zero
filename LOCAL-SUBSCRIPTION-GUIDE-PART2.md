# Local Subscription Guide (Part 2)

> Note: This is a continuation of LOCAL-SUBSCRIPTION-GUIDE.md. Please combine the contents of both files.

## Continuation of Step 5: Creating Utility Scripts

2. **Complete the check subscription status script**:

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
  EXPIRES_AT=$(echo $RESPONSE | grep -o '"lemonSqueezyRenewsAt":"[^"]*"' | cut -d'"' -f4)
  echo "   🔹 Expires: $(date -j -f "%Y-%m-%dT%H:%M:%S.000Z" "${EXPIRES_AT}" "+%Y-%m-%d" 2>/dev/null || date -d "${EXPIRES_AT}" "+%Y-%m-%d" 2>/dev/null || echo "${EXPIRES_AT}")"

  # Extract and display feature access
  BULK_UNSUBSCRIBE=$(echo $RESPONSE | grep -o '"bulkUnsubscribeAccess":"[^"]*"' | cut -d'"' -f4)
  AI_AUTOMATION=$(echo $RESPONSE | grep -o '"aiAutomationAccess":"[^"]*"' | cut -d'"' -f4)
  COLD_EMAIL=$(echo $RESPONSE | grep -o '"coldEmailBlockerAccess":"[^"]*"' | cut -d'"' -f4)

  echo "   🔹 Feature Access:"
  echo "      - Bulk Unsubscribe: $BULK_UNSUBSCRIBE"
  echo "      - AI Automation: $AI_AUTOMATION"
  echo "      - Cold Email Blocker: $COLD_EMAIL"
else
  echo "   ❌ No active premium subscription found"
fi

echo ""
echo "✅ Subscription check complete."
EOL

chmod +x check-subscription-status.sh
```

3. **Create a script to create a new subscription**:

```bash
cat > create-subscription.sh << 'EOL'
#!/bin/bash
# create-subscription.sh - Create a premium subscription in local development environment

# Default values
TIER="BUSINESS_ANNUALLY"
DURATION=12

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --tier)
      TIER="$2"
      shift 2
      ;;
    --duration)
      DURATION="$2"
      shift 2
      ;;
    --help)
      echo "Usage: ./create-subscription.sh [options]"
      echo ""
      echo "Options:"
      echo "  --tier VALUE     Set subscription tier (default: BUSINESS_ANNUALLY)"
      echo "                   Valid values: BASIC_MONTHLY, BASIC_ANNUALLY, PRO_MONTHLY, PRO_ANNUALLY,"
      echo "                                BUSINESS_MONTHLY, BUSINESS_ANNUALLY, LIFETIME"
      echo "  --duration N     Set subscription duration in months (default: 12)"
      echo "  --help           Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

echo "🔍 Creating premium subscription..."

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

# Create subscription
echo "🔹 Creating subscription with tier=$TIER, duration=$DURATION months"
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{\"tier\":\"$TIER\",\"durationMonths\":$DURATION}" \
  http://localhost:3000/api/dev/subscription)

# Check if we got a valid response
if [[ $RESPONSE == *"error"* ]]; then
  ERROR=$(echo $RESPONSE | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
  echo "❌ Error: $ERROR"
  if [[ $ERROR == *"Authentication required"* ]]; then
    echo "   Please make sure you're logged in to Inbox Zero."
  fi
  exit 1
fi

# Check if subscription was created successfully
if [[ $RESPONSE == *"success"* ]]; then
  MESSAGE=$(echo $RESPONSE | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
  echo "✅ Success: $MESSAGE"
  echo "   You now have an active premium subscription in your local environment."
  echo "   Run './check-subscription-status.sh' to verify the details."
else
  echo "❌ Unknown error occurred. Response: $RESPONSE"
  exit 1
fi
EOL

chmod +x create-subscription.sh
```

4. **Create a script to cancel a subscription**:

```bash
cat > cancel-subscription.sh << 'EOL'
#!/bin/bash
# cancel-subscription.sh - Cancel the current premium subscription

echo "🔍 Canceling premium subscription..."

# Check if the server is running
if ! curl -s http://localhost:3000 > /dev/null; then
  echo "❌ Error: Local server is not running. Please start it with './start-local.sh'"
  exit 1
fi

# Confirm cancellation
read -p "Are you sure you want to cancel your premium subscription? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ Cancellation aborted."
  exit 0
fi

# Cancel subscription
RESPONSE=$(curl -s -X DELETE http://localhost:3000/api/dev/subscription)

# Check if we got a valid response
if [[ $RESPONSE == *"error"* ]]; then
  ERROR=$(echo $RESPONSE | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
  echo "❌ Error: $ERROR"
  if [[ $ERROR == *"Authentication required"* ]]; then
    echo "   Please make sure you're logged in to Inbox Zero."
  fi
  exit 1
fi

# Check if subscription was canceled successfully
if [[ $RESPONSE == *"success"* ]]; then
  MESSAGE=$(echo $RESPONSE | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
  echo "✅ Success: $MESSAGE"
  echo "   Your premium subscription has been canceled."
else
  echo "❌ Unknown error occurred. Response: $RESPONSE"
  exit 1
fi
EOL

chmod +x cancel-subscription.sh
```

5. **Create a script to toggle premium mode on/off quickly**:

```bash
cat > toggle-subscription.sh << 'EOL'
#!/bin/bash
# toggle-subscription.sh - Quickly toggle between premium and free mode

echo "🔄 Checking current subscription status..."

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

# Get current subscription status
RESPONSE=$(curl -s -X GET http://localhost:3000/api/dev/subscription)

# Check if we got a valid response
if [[ $RESPONSE == *"error"* ]]; then
  ERROR=$(echo $RESPONSE | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
  echo "❌ Error: $ERROR"
  if [[ $ERROR == *"Authentication required"* ]]; then
    echo "   Please make sure you're logged in to Inbox Zero."
    echo "   Open http://localhost:3000 in your browser and sign in."
  fi
  exit 1
fi

# Parse subscription status
PREMIUM_ACTIVE=$(echo $RESPONSE | grep -o '"premiumActive":\s*\w\+' | cut -d: -f2 | tr -d ' ')

if [[ $PREMIUM_ACTIVE == "true" ]]; then
  echo "🔽 Currently in PREMIUM mode. Switching to FREE mode..."

  # Cancel subscription
  CANCEL_RESPONSE=$(curl -s -X DELETE http://localhost:3000/api/dev/subscription)

  if [[ $CANCEL_RESPONSE == *"success"* ]]; then
    echo "✅ Successfully switched to FREE mode."
  else
    echo "❌ Failed to switch to FREE mode."
    exit 1
  fi
else
  echo "🔼 Currently in FREE mode. Switching to PREMIUM mode..."

  # Create subscription
  CREATE_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"tier\":\"BUSINESS_ANNUALLY\",\"durationMonths\":12}" \
    http://localhost:3000/api/dev/subscription)

  if [[ $CREATE_RESPONSE == *"success"* ]]; then
    echo "✅ Successfully switched to PREMIUM mode."
  else
    echo "❌ Failed to switch to PREMIUM mode."
    exit 1
  fi
fi

echo ""
echo "🔄 You may need to refresh your browser to see the changes."
EOL

chmod +x toggle-subscription.sh
```

## Testing the Implementation

After completing the implementation, follow these steps to test it:

1. **Start the application**:

```bash
./start-local.sh
```

2. **Sign in to your account**:

   - Open `http://localhost:3000` in your browser
   - Sign in with your Google account

3. **Open the Subscription Manager**:

```bash
./open-subscription-manager.sh
```

This will open the subscription management UI in your browser.

4. **Create a Premium Subscription**:

   - Select the desired tier (e.g., BUSINESS_ANNUALLY)
   - Set the duration (e.g., 12 months)
   - Click "Create Subscription"

5. **Verify Premium Features**:

   - Navigate to different sections of the application to confirm premium features are working
   - Test bulk unsubscribe functionality
   - Check if AI automation is enabled
   - Verify cold email blocker functionality

6. **Test Managing the Subscription**:
   - Use the Subscription Manager to update your subscription tier
   - Test canceling and recreating the subscription
   - Use the toggle script to quickly switch between premium and free mode

## Troubleshooting Common Issues

### Issue: Authentication Errors

**Symptoms**: You receive "Authentication required" errors when trying to manage your subscription.

**Solutions**:

1. Make sure you're signed in to Inbox Zero:

   ```bash
   # Start the application if it's not running
   ./start-local.sh

   # Open in browser and sign in
   open http://localhost:3000
   ```

2. Check that your auth session is valid by viewing your profile in the application.

3. If issues persist, try clearing your browser cookies and signing in again.

### Issue: Database Connection Errors

**Symptoms**: You see database-related errors in the terminal when trying to manage subscriptions.

**Solutions**:

1. Verify your database is running:

   ```bash
   docker ps | grep postgres
   ```

2. Check your database connection settings in `.env.local`:

   ```bash
   cat .env.local | grep DATABASE_URL
   ```

3. Reset the database if needed:
   ```bash
   cd apps/web
   npx prisma migrate reset
   cd ../..
   ```

### Issue: Premium Features Still Restricted

**Symptoms**: Even after creating a subscription, some premium features are still not accessible.

**Solutions**:

1. Verify your subscription status:

   ```bash
   ./check-subscription-status.sh
   ```

2. Make sure the subscription has the correct feature access flags:

   ```bash
   # Open the Prisma Studio to check the database
   cd apps/web
   npx prisma studio
   # Look for Premium records and check their feature access settings
   ```

3. Try toggling the subscription off and on:

   ```bash
   ./toggle-subscription.sh
   ./toggle-subscription.sh
   ```

4. Restart your browser to ensure it loads fresh session data.

### Issue: UI Components Not Rendering Correctly

**Symptoms**: The subscription management UI has missing or broken components.

**Solutions**:

1. Make sure all required UI components are imported:

   - Check for import errors in the developer console
   - Verify that the shadcn/ui components are properly installed

2. Check for CSS conflicts or styling issues:

   - Inspect the elements in the browser developer tools
   - Look for any CSS class conflicts

3. Update Next.js and rebuild the application:
   ```bash
   cd apps/web
   npm run build
   npm run dev
   ```

## Appendix: Lemon Squeezy Integration (Optional)

If you want to test with an actual payment processor, you can integrate with Lemon Squeezy's sandbox environment:

1. **Create a Lemon Squeezy Account**:

   - Sign up at [lemonsqueezy.com](https://lemonsqueezy.com/)
   - Create a new store

2. **Set Up Test Products**:

   - Create test products that match your subscription tiers
   - Configure the pricing and recurring options

3. **Configure API Keys**:

   - Generate an API key in the Lemon Squeezy dashboard
   - Update your `.env.local` with the real API key:
     ```
     LEMON_SQUEEZY_API_KEY=your_actual_key
     LEMON_SQUEEZY_STORE_ID=your_store_id
     LEMON_SQUEEZY_WEBHOOK_SECRET=your_webhook_secret
     ```

4. **Set Up Webhooks**:

   - Configure a webhook in Lemon Squeezy to point to your local environment
   - Use a tool like ngrok to create a public URL that forwards to your local webhook endpoint:
     ```bash
     npx ngrok http 3000
     ```
   - Set the webhook URL to `https://your-ngrok-url.io/api/lemon-squeezy/webhook`

5. **Test the Full Payment Flow**:
   - Create a checkout link for one of your test products
   - Complete the purchase with Lemon Squeezy's test payment methods
   - Verify that the webhook is received and the subscription is created

Note that this full integration is optional and more complex. For most local development needs, the simpler approach described in the main guide is recommended.
