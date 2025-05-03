#!/bin/bash
# Script to toggle between FREE and PRO plan modes in schema.prisma
# Created as part of the PRD instructions for Inbox Zero local setup

MODE=$1

if [ "$MODE" == "pro" ]; then
    echo "Setting default plan to PRO mode..."
    sed -i '' 's/@default("FREE")/@default("PRO")/' apps/web/prisma/schema.prisma
elif [ "$MODE" == "free" ]; then
    echo "Setting default plan to FREE mode..."
    sed -i '' 's/@default("PRO")/@default("FREE")/' apps/web/prisma/schema.prisma
else
    echo "Usage: ./toggle-plan-mode.sh [pro|free]"
    exit 1
fi

echo "✅ Schema updated. Now run:"
echo "   pnpm prisma migrate dev --name toggle-plan-mode"
