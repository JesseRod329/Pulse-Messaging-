import type { ApiEnvelope } from "./types.ts";

export class ApiHttpError extends Error {
  readonly status: number;
  readonly code: string;

  constructor(status: number, code: string, message: string) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

export function requestId(req: Request): string {
  return req.headers.get("x-request-id") ?? crypto.randomUUID();
}

function baseHeaders(): HeadersInit {
  return {
    "content-type": "application/json; charset=utf-8",
  };
}

export function ok<T>(request_id: string, data: T, status = 200): Response {
  const envelope: ApiEnvelope<T> = {
    success: true,
    data,
    error: null,
    request_id,
  };
  return new Response(JSON.stringify(envelope), { status, headers: baseHeaders() });
}

export function fail(
  request_id: string,
  code: string,
  message: string,
  status = 400,
): Response {
  const envelope: ApiEnvelope<null> = {
    success: false,
    data: null,
    error: { code, message },
    request_id,
  };
  return new Response(JSON.stringify(envelope), { status, headers: baseHeaders() });
}

export async function readJson<T>(req: Request): Promise<T> {
  try {
    return await req.json() as T;
  } catch {
    throw new ApiHttpError(400, "invalid_json", "Request body must be valid JSON.");
  }
}

export function assert(condition: unknown, status: number, code: string, message: string): asserts condition {
  if (!condition) {
    throw new ApiHttpError(status, code, message);
  }
}

export function onError(request_id: string, error: unknown): Response {
  if (error instanceof ApiHttpError) {
    return fail(request_id, error.code, error.message, error.status);
  }

  const message = error instanceof Error ? error.message : "Unknown error";
  return fail(request_id, "internal_error", message, 500);
}
