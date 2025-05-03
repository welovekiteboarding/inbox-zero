/**
 * Direct Redis client using ioredis
 * Use as a fallback when Upstash Redis client has issues
 */

import Redis from "ioredis";
import { env } from "@/env";

// Parse the Redis URL to get host and port
// Default to localhost:6379 if parsing fails
const redisUrl = env.REDIS_URL || "redis://127.0.0.1:6379";

// Create a new Redis client
const redisClient = new Redis(redisUrl);

// Handle connection errors
redisClient.on("error", (err) => {
  console.error("Redis connection error:", err);
});

// Handle successful connection
redisClient.on("connect", () => {
  console.log("Connected to Redis successfully");
});

// Export a simplified API similar to Upstash Redis
export const directRedis = {
  get: async (key: string) => {
    try {
      return await redisClient.get(key);
    } catch (error) {
      console.error("Error in Redis get:", error);
      return null;
    }
  },

  set: async (key: string, value: string, expireInSeconds?: number) => {
    try {
      if (expireInSeconds) {
        return await redisClient.set(key, value, "EX", expireInSeconds);
      }
      return await redisClient.set(key, value);
    } catch (error) {
      console.error("Error in Redis set:", error);
      return null;
    }
  },

  expire: async (key: string, seconds: number) => {
    try {
      return await redisClient.expire(key, seconds);
    } catch (error) {
      console.error("Error in Redis expire:", error);
      return 0;
    }
  },

  del: async (key: string) => {
    try {
      return await redisClient.del(key);
    } catch (error) {
      console.error("Error in Redis del:", error);
      return 0;
    }
  },
};
