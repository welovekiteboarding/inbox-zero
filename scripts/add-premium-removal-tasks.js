#!/usr/bin/env node

/**
 * add-premium-removal-tasks.js
 * Script to add premium removal tasks to existing tasks.json without overwriting
 */

const fs = require('fs');
const path = require('path');

// Paths
const tasksJsonPath = path.join(__dirname, '..', 'tasks', 'tasks.json');
const tasksDir = path.join(__dirname, '..', 'tasks');

// Read existing tasks.json
const tasksData = JSON.parse(fs.readFileSync(tasksJsonPath, 'utf8'));
const currentTaskCount = tasksData.tasks.length;
const nextTaskId = currentTaskCount + 1;

// New tasks for premium removal
const newTasks = [
  {
    id: nextTaskId,
    title: "Patch premium plan checks for full access",
    description: "Modify the backend plan checks to always allow full feature access",
    status: "pending",
    dependencies: [7], // Depends on authentication working
    priority: "medium",
    details: "1. Identify the plan.ts file in the apps/web/utils/premium directory\n2. Modify the premium checking functions to always return true\n3. Ensure all feature limitations are bypassed\n4. Test that premium features work without restrictions",
    testStrategy: "Test premium features that were previously limited to ensure they now work without any upgrade prompts or restrictions.",
    tags: ["premium", "patch", "enhancement"],
    owner: "me",
    estimatedDuration: 45
  },
  {
    id: nextTaskId + 1,
    title: "Remove upgrade modals and redirects",
    description: "Disable the premium upgrade modals and redirects to prevent interruptions",
    status: "pending",
    dependencies: [nextTaskId],
    priority: "medium",
    details: "1. Find the upgrade modal components in the codebase\n2. Modify them to return null or not display\n3. Disable any redirects to upgrade pages\n4. Ensure a clean user experience without upgrade interruptions",
    testStrategy: "Verify that no upgrade modals appear when using features that would normally trigger them, and that there are no redirects to upgrade pages.",
    tags: ["premium", "ui", "enhancement"],
    owner: "me",
    estimatedDuration: 30
  },
  {
    id: nextTaskId + 2,
    title: "Default users to PRO plan in database schema",
    description: "Modify the Prisma schema to set all users to PRO plan by default",
    status: "pending",
    dependencies: [nextTaskId + 1],
    priority: "low",
    details: "1. Locate the User model in the Prisma schema\n2. Change the default plan value from \"FREE\" to \"PRO\"\n3. Run Prisma migration to apply the change\n4. Ensure new users are automatically created with PRO status",
    testStrategy: "Create a new user account and verify it has PRO status in the database. Confirm access to premium features.",
    tags: ["premium", "database", "enhancement"],
    owner: "me",
    estimatedDuration: 30
  },
  {
    id: nextTaskId + 3,
    title: "Create helper scripts for plan management",
    description: "Develop utility scripts for toggling and checking plan modes",
    status: "pending",
    dependencies: [nextTaskId + 2],
    priority: "low",
    details: "1. Create toggle-plan-mode.sh for switching between FREE and PRO modes\n2. Develop check-plan-default.sh to check current plan status\n3. Create reset-db-and-migrate.sh for database reset and migration\n4. Make dev-bootstrap.sh for one-click environment startup\n5. Create backup-postgres.sh for database backup",
    testStrategy: "Test each script to ensure it performs its function correctly. Verify plan toggling works and check script accurately reports plan status.",
    tags: ["premium", "scripts", "enhancement"],
    owner: "me",
    estimatedDuration: 60
  }
];

// Add new tasks to tasks.json
tasksData.tasks = [...tasksData.tasks, ...newTasks];
tasksData.metadata.totalTasks = tasksData.tasks.length;

// Write updated tasks.json
fs.writeFileSync(tasksJsonPath, JSON.stringify(tasksData, null, 2), 'utf8');

// Create individual task files
newTasks.forEach(task => {
  const taskFilePath = path.join(tasksDir, `task_${String(task.id).padStart(3, '0')}.txt`);
  
  const taskContent = `# Task ${task.id}: ${task.title}

## Description
${task.description}

## Details
${task.details}

## Test Strategy
${task.testStrategy}

## Priority
${task.priority}

## Dependencies
${task.dependencies.join(', ')}

## Status
${task.status}

## Tags
${task.tags.join(', ')}
`;

  fs.writeFileSync(taskFilePath, taskContent, 'utf8');
});

console.log(`✅ Added ${newTasks.length} new tasks for premium feature removal.`);
console.log(`Total tasks: ${tasksData.tasks.length}`);
