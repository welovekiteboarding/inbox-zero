# HOW TO STARTUP AND RUN INBOX ZERO

This document provides detailed instructions for starting and running the Inbox Zero application locally.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- [Node.js](https://nodejs.org/) v22.0.0 or higher
- [pnpm](https://pnpm.io/) v10.8.1 or higher
- Google OAuth credentials configured
- Git (for cloning the repository)

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/elie222/inbox-zero.git
cd inbox-zero
```

### 2. Install Dependencies

```bash
pnpm install
```

This will install all dependencies for the monorepo, including packages in the apps/web directory.

## Environment Configuration

Inbox Zero requires proper environment configuration to run. Create the following environment files:

### 1. Root-level `.env.local`:

Create a file called `.env.local` in the project root with the following content:

```
# Database connection
DATABASE_URL=postgresql://inbox:inboxpassword@localhost:5432/inboxdb
DIRECT_URL=postgresql://inbox:inboxpassword@localhost:5432/inboxdb
REDIS_URL=redis://localhost:6379

# Redis configuration
# IMPORTANT: Use standard Redis protocol for local Redis
UPSTASH_REDIS_URL=redis://localhost:6379
UPSTASH_REDIS_TOKEN=inboxzerosupersecretkeyforlocaldev

# Next.js and Authentication
NEXTAUTH_SECRET=inboxzerosupersecretkeyforlocaldev
NEXTAUTH_URL=http://localhost:3000
JWT_SECRET=inboxzerosupersecretkeyforlocaldev
INTERNAL_API_KEY=inboxzerosupersecretkeyforlocaldev
API_KEY_SALT=inboxzerosupersecretkey

# Google OAuth credentials
# Replace with your actual Google OAuth credentials
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret
NEXT_PUBLIC_GOOGLE_REDIRECT_URI=http://localhost:3000/api/auth/callback/google

# Google Pub/Sub (required for email notifications)
GOOGLE_PUBSUB_TOPIC_NAME="projects/inbox-zero-local-458200/topics/gmail-notifications"
GOOGLE_PUBSUB_VERIFICATION_TOKEN=inboxzerosupersecretkeyforlocaldev

# Required encryption secrets
GOOGLE_ENCRYPT_SECRET=inboxzerosupersecretkeyforlocaldevinboxzerosupersecretkeyforlocaldev
GOOGLE_ENCRYPT_SALT=inboxzerosupersecretkeyforlocaldev

# LLM config - OpenAI is recommended for local development
DEFAULT_LLM_PROVIDER=openai
OPENAI_API_KEY=your-openai-api-key

# Environment setting
NODE_ENV=development
NEXT_PUBLIC_APP_HOME_PATH=/automation
LOG_ZOD_ERRORS=true
```

### 2. Web App Environment File:

Create a file at `apps/web/.env.local` with the same content as the root `.env.local`. This ensures both config files have consistent settings.

### 3. Getting Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project if needed
3. Navigate to APIs & Services > Credentials
4. Create OAuth 2.0 Client ID credentials for a Web application
5. Add the following authorized redirect URI:
   ```
   http://localhost:3000/api/auth/callback/google
   ```
6. Save and copy the Client ID and Client Secret to your `.env.local` files

### 4. Google API Configuration

1. In the Google Cloud Console project, enable the following APIs:
   - Gmail API
   - Google Pub/Sub API
   - People API

## Database Configuration

### 1. Start Database Services

Start the required PostgreSQL and Redis containers using Docker Compose:

```bash
docker-compose up -d
```

This command starts the following services:

- PostgreSQL on port 5432
- Redis on port 6379

Verify the containers are running:

```bash
docker ps
```

You should see both the postgres and redis containers with "Up" status:

```
CONTAINER ID   IMAGE      COMMAND                  STATUS         PORTS                    NAMES
123456789abc   redis      "redis-server --bind…"   Up 2 minutes   0.0.0.0:6379->6379/tcp   inbox-zero-redis-1
987654321def   postgres   "postgres"               Up 2 minutes   0.0.0.0:5432->5432/tcp   inbox-zero-postgres-1
```

### 2. Initialize the Database (First-time Setup)

Initialize the database schema:

```bash
cd apps/web
npx prisma generate
npx prisma migrate deploy
cd ../..
```

This creates all necessary database tables and prepares the schema.

## Redis Configuration for Local Development

### Understanding Redis Client Requirements

Inbox Zero uses the Upstash Redis client by default, which has specific requirements:

1. **Important**: The Upstash Redis client requires HTTPS URLs when used in cloud environments, but this doesn't work for local development.

2. For local development, we use a modified configuration that:
   - Uses the standard Redis protocol (`redis://localhost:6379`)
   - Uses the direct `ioredis` client for local development

### Verifying Redis Connection

After starting the Docker containers:

1. Test direct Redis connection:

```bash
docker exec inbox-zero-redis-1 redis-cli -h 127.0.0.1 ping
```

You should receive `PONG` as a response, confirming Redis is accessible.

## Starting the Web Application

The application MUST run on port 3000 for Google OAuth to work correctly.

### 1. Ensure Port 3000 is Available

Check if any process is using port 3000:

```bash
lsof -i :3000
```

If anything is using port 3000, terminate it:

```bash
lsof -ti:3000 | xargs kill -9
```

### 2. Start the Web Application

Option A: Direct Start (Recommended)

```bash
cd apps/web
PORT=3000 npm run dev
```

Option B: Using the Start Script

```bash
chmod +x start-local.sh
./start-local.sh
```

### 3. Verify Startup

Check the console output to confirm the application is running on port 3000:

```
- Local:        http://localhost:3000
```

Access the application in your browser at:

```
http://localhost:3000
```

### 4. Complete Initial Authentication

1. Click "Sign in with Google" on the login page
2. Complete the Google authentication flow
3. Grant the requested Gmail access permissions
4. You'll be redirected to the Inbox Zero dashboard

## Troubleshooting Common Issues

### Port 3000 is Already in Use

If the application tries to start on a different port (e.g., 3001):

1. Kill any process using port 3000:

```bash
lsof -ti:3000 | xargs kill -9
```

2. Verify port 3000 is free:

```bash
lsof -i :3000
```

3. Restart the application with the port explicitly set:

```bash
cd apps/web
PORT=3000 npm run dev
```

### Database Connection Issues

If you encounter database connection errors:

1. Verify Docker containers are running:

```bash
docker ps
```

2. Check the database connection settings:

```bash
cat .env.local | grep DATABASE_URL
cat apps/web/.env.local | grep DATABASE_URL
```

3. Ensure the PostgreSQL container is healthy:

```bash
docker logs inbox-zero-postgres-1
```

4. Test direct database connection:

```bash
docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -c "SELECT 1;"
```

### Redis Connection Errors

If you see Redis connection errors in the console:

1. **Common Error**: `Error [UrlError]: Upstash Redis client was passed an invalid URL. You should pass a URL starting with https. Received: "redis://127.0.0.1:6379"`

   **Solution**: The Upstash Redis client expects HTTPS URLs, but local Redis doesn't support HTTPS. You have two options:

   a) Use the direct Redis client (recommended):

   - Modify `apps/web/utils/redis/index.ts` to use the direct Redis client
   - Set `REDIS_URL=redis://localhost:6379` in your environment files

   b) If Redis errors persist, check the Redis container:

   ```bash
   docker logs inbox-zero-redis-1
   ```

2. If you see `ECONNREFUSED` errors:

   - Ensure Redis container is running
   - Check that the Redis port (6379) is correctly mapped and accessible

3. Test direct Redis connection:

```bash
docker exec inbox-zero-redis-1 redis-cli -h 127.0.0.1 ping
```

### No Emails Showing Up

If you've authenticated but no emails appear:

1. Check browser console for errors
2. Verify database tables were created:

```bash
docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';"
```

3. Check for email records:

```bash
docker exec inbox-zero-postgres-1 psql -U inbox -d inboxdb -c "SELECT COUNT(*) FROM \"EmailMessage\";"
```

4. Ensure your Google Cloud project has the Gmail API enabled and correct permissions

### Authentication Failures

If you cannot log in with Google:

1. Verify the application is running on port 3000 (required for OAuth callbacks)

2. Check your Google OAuth credentials:

```bash
cat .env.local | grep GOOGLE_CLIENT
```

3. Ensure the redirect URI in your Google Cloud Console matches exactly:

```
http://localhost:3000/api/auth/callback/google
```

4. Verify you've enabled the necessary Google APIs (Gmail, Pub/Sub, People)

## Complete Startup Workflow

For a reliable startup every time:

1. **Start clean:**

```bash
# Kill any running instances
pkill -f "npm run dev"
pkill -f "next dev"

# Free up port 3000
lsof -ti:3000 | xargs kill -9
```

2. **Start services:**

```bash
docker-compose up -d
```

3. **Start application on port 3000:**

```bash
cd apps/web
PORT=3000 npm run dev
```

4. **Access the application and authenticate:**
   Open http://localhost:3000 in your browser and sign in

## Shutting Down

To properly shut down Inbox Zero:

1. Stop the Next.js server with Ctrl+C

2. Stop Docker containers:

```bash
docker-compose down
```

## Using Alternative Start Scripts

The repository includes several helpful scripts:

- `./start-local.sh` - Standard startup script
- `./force-port-3000.sh` - Kills anything on port 3000 and starts the app
- `./start-port-3000.sh` - Specifically runs on port 3000

Make these scripts executable first:

```bash
chmod +x start-local.sh
chmod +x force-port-3000.sh
chmod +x start-port-3000.sh
```

For the most reliable startup approach:

```bash
./force-port-3000.sh
```

## Environment Variables Reference

Key environment variables required for Inbox Zero:

| Variable             | Description                       | Required Value for Local Dev                            |
| -------------------- | --------------------------------- | ------------------------------------------------------- |
| DATABASE_URL         | PostgreSQL connection string      | postgresql://inbox:inboxpassword@localhost:5432/inboxdb |
| REDIS_URL            | Redis connection string           | redis://localhost:6379                                  |
| UPSTASH_REDIS_URL    | Upstash Redis URL (for local dev) | redis://localhost:6379                                  |
| UPSTASH_REDIS_TOKEN  | Token for Redis access            | Any string value for local dev                          |
| GOOGLE_CLIENT_ID     | Google OAuth client ID            | From Google Cloud Console                               |
| GOOGLE_CLIENT_SECRET | Google OAuth client secret        | From Google Cloud Console                               |
| NEXTAUTH_SECRET      | Secret for NextAuth.js            | Any secure random string                                |
| NEXTAUTH_URL         | NextAuth URL                      | http://localhost:3000                                   |
| NODE_ENV             | Environment setting               | development                                             |
| DEFAULT_LLM_PROVIDER | Which AI provider to use          | openai, anthropic, bedrock, etc.                        |
| OPENAI_API_KEY       | OpenAI API key                    | Required if using OpenAI                                |

## Files You Might Need to Modify for Local Development

If you encounter Redis connection issues, you may need to modify these files:

1. **apps/web/utils/redis/index.ts** - The main Redis client configuration
2. **apps/web/utils/redis-direct.ts** - A direct Redis client for local development
3. **apps/web/.env.local** - Environment variables for the web app

## Monitoring Application Logs

Watch the terminal output for:

1. **Redis Connection Errors**:

   - `Redis connection error: [Error: connect ENOTSOCK /]`
   - `Error [UrlError]: Upstash Redis client was passed an invalid URL`

2. **Authentication Status**:

   - `JWT Callback - inputs`
   - `NextAuth processing request`

3. **Database Interactions**:
   - Prisma query logs
   - Any database connection errors

Monitor these logs to identify and resolve any issues that arise during startup and operation.
