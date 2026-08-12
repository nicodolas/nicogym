import { createHmac, timingSafeEqual } from "node:crypto";

import type { ExerciseImport } from "./exercise-schema.js";

export interface ImportPreviewPayload extends ExerciseImport {
  adminUserId: string;
  catalogRevision: string;
  expiresAt: number;
}

export function signImportPreview(payload: ImportPreviewPayload, secret: string): string {
  const encoded = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const signature = createHmac("sha256", secret).update(encoded).digest("base64url");
  return `${encoded}.${signature}`;
}

export function verifyImportPreview(token: string, secret: string): ImportPreviewPayload {
  const [encoded, suppliedSignature, extra] = token.split(".");
  if (!encoded || !suppliedSignature || extra) throw new Error("invalid_preview_token");
  const expected = createHmac("sha256", secret).update(encoded).digest();
  const supplied = Buffer.from(suppliedSignature, "base64url");
  if (supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
    throw new Error("invalid_preview_token");
  }
  const payload = JSON.parse(Buffer.from(encoded, "base64url").toString("utf8")) as ImportPreviewPayload;
  if (payload.expiresAt <= Date.now()) throw new Error("preview_expired");
  return payload;
}
