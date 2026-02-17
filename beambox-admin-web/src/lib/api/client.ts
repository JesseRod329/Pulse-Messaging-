import type { ApiEnvelope } from "./types";

export type EdgeFunctionName =
  | "inventory-list"
  | "inventory-adjust-stock"
  | "admin-orders-list"
  | "admin-delete-order"
  | "admin-unassign-driver"
  | "admin-routes-list"
  | "admin-channel-members-list"
  | "admin-driver-memberships-upsert"
  | "admin-member-role-upsert"
  | "admin-audit-events-list"
  | "admin-archive-channel"
  | "admin-dashboard-summary";

interface EnvShape {
  [key: string]: string | undefined;
}

export interface EdgeCallOptions {
  authToken: string;
  signal?: AbortSignal;
  baseUrl?: string;
}

export class ApiClientError extends Error {
  status: number;
  code: string;
  requestId: string | null;
  details: unknown;

  constructor(params: {
    status: number;
    code: string;
    message: string;
    requestId?: string | null;
    details?: unknown;
  }) {
    super(params.message);
    this.name = "ApiClientError";
    this.status = params.status;
    this.code = params.code;
    this.requestId = params.requestId ?? null;
    this.details = params.details ?? null;
  }

  get isRateLimited(): boolean {
    return this.status === 429 || this.code === "rate_limited";
  }
}

function envValue(name: string): string | undefined {
  const meta = import.meta as ImportMeta & { env?: EnvShape };
  return meta.env?.[name];
}

function functionsBaseUrl(baseUrlOverride?: string): string {
  const explicit = (baseUrlOverride ?? envValue("VITE_SUPABASE_FUNCTIONS_BASE_URL"))?.trim();
  if (explicit) return explicit.replace(/\/$/, "");

  const supabaseUrl = envValue("VITE_SUPABASE_URL")?.trim();
  if (!supabaseUrl) {
    throw new ApiClientError({
      status: 500,
      code: "config_missing",
      message:
        "Missing VITE_SUPABASE_URL or VITE_SUPABASE_FUNCTIONS_BASE_URL. Set one in the admin web environment.",
    });
  }

  return `${supabaseUrl.replace(/\/$/, "")}/functions/v1`;
}

function asEnvelope<T>(value: unknown): ApiEnvelope<T> | null {
  if (!value || typeof value !== "object") return null;
  const probe = value as Record<string, unknown>;
  if (typeof probe.success !== "boolean") return null;
  if (typeof probe.request_id !== "string") return null;
  if (!("data" in probe) || !("error" in probe)) return null;
  return value as ApiEnvelope<T>;
}

export async function postEdge<TRequest extends object, TResponse>(
  functionName: EdgeFunctionName,
  payload: TRequest,
  options: EdgeCallOptions,
): Promise<TResponse> {
  const authToken = options.authToken.trim();
  if (!authToken) {
    throw new ApiClientError({
      status: 401,
      code: "auth_missing",
      message: "Owner access token is required.",
    });
  }

  const anonKey = envValue("VITE_SUPABASE_ANON_KEY")?.trim();
  const endpoint = `${functionsBaseUrl(options.baseUrl)}/${functionName}`;
  const headers: Record<string, string> = {
    "content-type": "application/json",
    authorization: `Bearer ${authToken}`,
  };
  if (anonKey) {
    headers.apikey = anonKey;
  }

  const response = await fetch(endpoint, {
    method: "POST",
    headers,
    body: JSON.stringify(payload),
    signal: options.signal,
  });

  let json: unknown = null;
  try {
    json = await response.json();
  } catch {
    json = null;
  }

  const envelope = asEnvelope<TResponse>(json);

  if (!response.ok) {
    const errorObject = envelope?.error;
    throw new ApiClientError({
      status: response.status,
      code: errorObject?.code ?? "http_error",
      message: errorObject?.message ?? `Request failed with status ${response.status}.`,
      requestId: envelope?.request_id ?? null,
      details: envelope,
    });
  }

  if (!envelope) {
    throw new ApiClientError({
      status: 500,
      code: "invalid_envelope",
      message: "Edge function returned a non-standard response envelope.",
      details: json,
    });
  }

  if (!envelope.success || envelope.data == null) {
    throw new ApiClientError({
      status: 500,
      code: envelope.error?.code ?? "edge_error",
      message: envelope.error?.message ?? "Edge function call returned no data.",
      requestId: envelope.request_id,
      details: envelope,
    });
  }

  return envelope.data;
}
