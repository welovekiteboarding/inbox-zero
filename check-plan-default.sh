#!/bin/bash
# Script to check current plan default status (FREE or PRO) in schema.prisma
# Created as part of the PRD instructions for Inbox Zero local setup

DEFAULT_PLAN=$(grep 'plan String @default' apps/web/prisma/schema.prisma)

if echo "$DEFAULT_PLAN" | grep -q 'FREE'; then
    echo "❄️ Current default plan is: FREE"
elif echo "$DEFAULT_PLAN" | grep -q 'PRO'; then
    echo "🔥 Current default plan is: PRO"
else
    echo "⚠️ Unable to detect plan default. Please check schema.prisma manually."
fi
