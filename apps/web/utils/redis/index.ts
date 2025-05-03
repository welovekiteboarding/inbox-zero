import { env } from "@/env";
import { directRedis } from "../redis-direct";

// For local development, we use the standard Redis client directly
// This avoids issues with Upstash Redis client which requires special URL formats
console.log("Using direct Redis client for local development");

// Export the direct Redis client
export const redis = directRedis;

// Maintain compatibility with the original export
export async function expire(key: string, seconds: number) {
  return redis.expire(key, seconds);
}
