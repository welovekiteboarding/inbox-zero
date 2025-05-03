# Inbox Zero Troubleshooting Guide

## Redis Connection Errors

If you see errors related to Redis in the console like:

```
eval@
(action-browser)/./utils/redis/index.ts@
__webpack_require__@
```

This indicates issues with the Redis connection in server actions. Possible fixes:

1. **Check Redis Connection String**:

   - For Upstash Redis client, use `UPSTASH_REDIS_URL=https://localhost:6379` (must use https:// protocol)
   - For standard Redis, use `REDIS_URL=redis://localhost:6379`
   - Verify Redis container is running: `docker ps | grep redis`

2. **Redis Initialization**:

   - Redis might not be fully initialized when the application tries to connect
   - Try restarting the Redis container: `docker-compose restart redis`
   - Increase the wait time before starting the application

3. **Clear Application Cache**:
   - Remove Next.js cache: `rm -rf apps/web/.next`
   - Restart the application

## Authentication Issues

If you encounter "Error Logging In" when trying to log in to Inbox Zero, check for these common issues:

1. **Missing Database Schema**:

   - The PostgreSQL database needs to have migrations applied
   - Solution: Run `cd apps/web && pnpm prisma migrate deploy`
   - Without these migrations, authentication tables won't exist

2. **Incorrect Redis URL**:

   - Redis must use `redis://` protocol, not `https://`
   - Check both `.env.local` and `apps/web/.env.local` files
   - Correct format: `UPSTASH_REDIS_URL=redis://localhost:6379`

3. **Port Issues**:
   - Inbox Zero must run on port 3000 due to Google OAuth configuration
   - If port 3000 is in use, run `./force-port-3000.sh` to kill processes and start on the correct port

## Complete Reset Process

If you need to completely reset the application:

```bash
# 1. Stop everything
./stop-local.sh

# 2. Kill any lingering processes on port 3000
lsof -i :3000 | grep LISTEN  # Find the PID
kill -9 <PID>                # Kill the process

# 3. Completely remove Docker containers and volumes
docker-compose down -v

# 4. Start fresh Docker containers
docker-compose up -d

# 5. Wait for containers to be ready
sleep 10

# 6. Apply all database migrations
cd apps/web && pnpm prisma migrate deploy

# 7. Clear Next.js build cache
rm -rf apps/web/.next

# 8. Return to root directory and start the application
cd ../.. && ./start-local.sh
```

## Environment Requirements

- Ensure `.env.local` exists in BOTH the root directory AND `apps/web/`
- Required environment variables:
  - `DATABASE_URL` and `DIRECT_URL` for PostgreSQL
  - `REDIS_URL` and `UPSTASH_REDIS_URL` for Redis
  - `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` for OAuth
  - `NEXTAUTH_SECRET` and `JWT_SECRET` for authentication

## Google OAuth Configuration

- Redirect URI must be: `http://localhost:3000/api/auth/callback/google`
- Required scopes:
  - `https://www.googleapis.com/auth/userinfo.profile`
  - `https://www.googleapis.com/auth/userinfo.email`
  - `https://www.googleapis.com/auth/gmail.modify`
  - `https://www.googleapis.com/auth/gmail.settings.basic`
