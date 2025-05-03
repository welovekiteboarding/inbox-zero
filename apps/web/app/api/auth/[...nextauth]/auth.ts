import NextAuth from "next-auth";
import { getAuthOptions, authOptions } from "@/utils/auth";
import { createScopedLogger } from "@/utils/logger";

const logger = createScopedLogger("Auth API");

export const {
  handlers: { GET, POST },
  auth,
  signOut,
} = NextAuth((req) => {
  try {
    console.log("[DEBUG] NextAuth processing request:", req?.url);

    if (req?.url) {
      const url = new URL(req?.url);
      const consent = url.searchParams.get("consent");
      console.log("[DEBUG] URL params:", {
        fullUrl: req.url,
        consent,
        error: url.searchParams.get("error"),
        callback: url.searchParams.get("callback"),
      });

      if (consent) {
        logger.info("Consent requested");
        console.log("[DEBUG] Using consent options");
        return getAuthOptions({ consent: true });
      }
    }

    console.log("[DEBUG] Using default auth options");
    return authOptions;
  } catch (error) {
    console.error("[DEBUG] Auth configuration error:", error);
    logger.error("Auth configuration error", { error });
    throw error;
  }
});
