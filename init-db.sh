#!/bin/bash

echo "🚀 Starting Prisma Database Initialization..."

# Step 1: Install Prisma Client (if not already installed)
echo "📦 Ensuring dependencies are installed..."
pnpm install

# Step 2: Generate Prisma Client Code
echo "🔧 Generating Prisma client..."
pnpm prisma generate

# Step 3: Run Database Migration (Deploy)
echo "🛠️ Running Prisma migrations to initialize database schema..."
pnpm prisma migrate deploy

echo "✅ Prisma database setup completed successfully."