export class SupabaseRequestError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

if (!supabaseUrl || !serviceRoleKey || !anonKey) {
  throw new Error("Missing SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, or SUPABASE_ANON_KEY.");
}

const SUPABASE_URL: string = supabaseUrl;
const SERVICE_ROLE_KEY: string = serviceRoleKey;
const ANON_KEY: string = anonKey;

function adminHeaders(preferRepresentation = false): Headers {
  const headers = new Headers();
  headers.set("content-type", "application/json");
  headers.set("apikey", SERVICE_ROLE_KEY);
  headers.set("authorization", `Bearer ${SERVICE_ROLE_KEY}`);

  if (preferRepresentation) {
    headers.set("prefer", "return=representation");
  }

  return headers;
}

async function parsePayload(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) {
    return null;
  }

  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function handleResponse(response: Response): Promise<unknown> {
  const payload = await parsePayload(response);

  if (!response.ok) {
    const message = typeof payload === "object" && payload && "message" in payload
      ? String((payload as { message: string }).message)
      : `Supabase request failed with status ${response.status}`;
    throw new SupabaseRequestError(response.status, message);
  }

  return payload;
}

export async function adminGet(path: string): Promise<unknown> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: "GET",
    headers: adminHeaders(false),
  });
  return handleResponse(response);
}

export async function adminPost(path: string, body: unknown): Promise<unknown> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: "POST",
    headers: adminHeaders(true),
    body: JSON.stringify(body),
  });
  return handleResponse(response);
}

export async function adminPatch(path: string, body: unknown): Promise<unknown> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: "PATCH",
    headers: adminHeaders(true),
    body: JSON.stringify(body),
  });
  return handleResponse(response);
}

export async function adminDelete(path: string): Promise<unknown> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: "DELETE",
    headers: adminHeaders(true),
  });
  return handleResponse(response);
}

export async function adminRpc(fnName: string, body: unknown): Promise<unknown> {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fnName}`, {
    method: "POST",
    headers: adminHeaders(false),
    body: JSON.stringify(body),
  });
  return handleResponse(response);
}

export async function authUserFromToken(token: string): Promise<unknown> {
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    method: "GET",
    headers: new Headers({
      "apikey": ANON_KEY,
      "authorization": `Bearer ${token}`,
    }),
  });

  return handleResponse(response);
}
