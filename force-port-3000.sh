#!/bin/bash
# Aggressively kills ALL processes using port 3000 and forces Inbox Zero to run on that port
# Created to ensure compatibility with Google OAuth redirect URI

echo "Aggressively killing ALL processes on port 3000..."
# Different ways to find processes on port 3000
lsof -ti:3000 | xargs kill -9 2>/dev/null
pkill -f "PORT=3000" 2>/dev/null
pkill -f "localhost:3000" 2>/dev/null

# Double-check that port 3000 is truly free
if lsof -ti:3000 >/dev/null; then
  echo "CRITICAL ERROR: Could not free port 3000 despite multiple attempts."
  echo "Please manually check what's using port 3000 with: lsof -i :3000"
  exit 1
fi

echo "✅ Port 3000 is confirmed free."

# Start Inbox Zero with port 3000 explicitly set
echo "Starting Inbox Zero on port 3000..."
cd "$(dirname "$0")"
PORT=3000 pnpm dev
