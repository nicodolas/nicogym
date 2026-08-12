import { describe, expect, it } from "vitest";

import { signImportPreview, verifyImportPreview } from "../src/catalog/import-token.js";

const secret = "test-secret-that-is-long-enough-for-hmac";
const payload = {
  mode: "create" as const,
  exercises: [],
  adminUserId: "admin-1",
  catalogRevision: "0:none",
  expiresAt: Date.now() + 60_000,
};

describe("exercise import preview token", () => {
  it("round trips a signed preview", () => {
    expect(verifyImportPreview(signImportPreview(payload, secret), secret)).toEqual(payload);
  });

  it("rejects tampering and expiry", () => {
    const token = signImportPreview(payload, secret);
    expect(() => verifyImportPreview(`${token}x`, secret)).toThrow("invalid_preview_token");
    const expired = signImportPreview({ ...payload, expiresAt: Date.now() - 1 }, secret);
    expect(() => verifyImportPreview(expired, secret)).toThrow("preview_expired");
  });
});
