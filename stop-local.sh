#!/bin/bash
# Created for Task #5: One-click stop script for Inbox Zero local development

echo "🛑 Stopping Inbox Zero Local Development Environment..."

# Step 1: Stop pnpm dev server if running (optional manual)
# Note: You'll usually Ctrl+C the dev server in your terminal manually.
# Here, we mainly stop the containers.

# Step 2: Bring down Docker containers
echo "🐳 Stopping Docker containers (Postgres and Redis)..."
docker-compose down

# Final confirmation
echo "✅ Docker containers stopped."
echo "🏁 Inbox Zero local environment fully shut down."
