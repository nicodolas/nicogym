interface RateLimitOptions {
  limit: number;
  windowMs: number;
  now?: () => number;
}

interface RateLimitEntry {
  count: number;
  resetAt: number;
}

export function createFixedWindowRateLimiter({
  limit,
  windowMs,
  now = Date.now,
}: RateLimitOptions) {
  const entries = new Map<string, RateLimitEntry>();

  return {
    consume(key: string) {
      const currentTime = now();
      const existing = entries.get(key);

      if (!existing || existing.resetAt <= currentTime) {
        entries.set(key, { count: 1, resetAt: currentTime + windowMs });
        return true;
      }

      if (existing.count >= limit) return false;

      existing.count += 1;
      return true;
    },
  };
}
