#!/bin/bash
# Force the Inbox Zero application to run on port 3000 only
# Created to ensure the app runs on the exact port required by Google OAuth

# Kill any processes currently using port 3000
echo "Killing any processes on port 3000..."
lsof -ti:3000 | xargs kill -9 2>/dev/null

# Verify port is free
if lsof -ti:3000 >/dev/null; then
  echo "ERROR: Could not free port 3000. Please check manually."
  exit 1
fi

echo "Port 3000 is free. Starting Inbox Zero..."

# Force Next.js to use port 3000 only
cd "$(dirname "$0")"
PORT=3000 pnpm dev
