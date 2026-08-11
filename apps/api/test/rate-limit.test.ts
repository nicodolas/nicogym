import { describe, expect, it } from "vitest";

import { createFixedWindowRateLimiter } from "../src/rate-limit.js";

describe("fixed-window rate limiter", () => {
  it("blocks requests over the limit and resets after the window", () => {
    let now = 1_000;
    const limiter = createFixedWindowRateLimiter({
      limit: 2,
      windowMs: 60_000,
      now: () => now,
    });

    expect(limiter.consume("user-1")).toBe(true);
    expect(limiter.consume("user-1")).toBe(true);
    expect(limiter.consume("user-1")).toBe(false);

    now += 60_001;
    expect(limiter.consume("user-1")).toBe(true);
  });

  it("keeps counters isolated per authenticated user", () => {
    const limiter = createFixedWindowRateLimiter({ limit: 1, windowMs: 60_000 });

    expect(limiter.consume("user-1")).toBe(true);
    expect(limiter.consume("user-1")).toBe(false);
    expect(limiter.consume("user-2")).toBe(true);
  });
});
