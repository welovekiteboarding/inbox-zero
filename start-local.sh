#!/bin/bash
# Created for Task #5: One-click start script for Inbox Zero local development

echo "🚀 Starting Inbox Zero Local Development Environment..."

# Step 1: Start Docker containers
echo "🐳 Starting Docker containers for Postgres and Redis..."
docker-compose up -d

# Step 2: Wait for containers to be ready
echo "⌛ Waiting 5 seconds for Postgres and Redis to be fully available..."
sleep 5

# Step 3: Run local development server
echo "🖥️ Starting Inbox Zero dev server (pnpm dev)..."
pnpm dev &

# Step 4: Open browser automatically
sleep 3
echo "🌐 Opening http://localhost:3000 in your default browser..."
if which xdg-open > /dev/null
then
  xdg-open http://localhost:3000
elif which open > /dev/null
then
  open http://localhost:3000
elif which start > /dev/null
then
  start http://localhost:3000
fi

# Final confirmation
echo "✅ All systems started. Inbox Zero is running at http://localhost:3000"
