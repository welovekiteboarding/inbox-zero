// Created to test direct database connectivity with Prisma for troubleshooting OAuth login errors
// This script will attempt to connect to the database with the current environment settings
// Run with: node db-test.js

const { PrismaClient } = require('@prisma/client');

async function main() {
  console.log('Attempting to connect to the database...');
  
  try {
    const prisma = new PrismaClient();
    await prisma.$connect();
    console.log('✅ Database connection successful!');
    
    // Try to query the User table to ensure it exists
    const userCount = await prisma.user.count();
    console.log(`Found ${userCount} users in the database.`);
    
    await prisma.$disconnect();
    console.log('Database connection closed.');
  } catch (error) {
    console.error('❌ Error connecting to database:', error);
  }
}

main();
