import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { adminGet, SupabaseRequestError } from "../_shared/supabase.ts";

interface AdminAuditEventsListBody {
  channel_id: string;
  action?: string;
  target_id?: string;
  limit?: number;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminAuditEventsListBody>(req);
    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");

    await requireChannelRole(body.channel_id, user.id, "owner");

    const limit = Math.max(1, Math.min(body.limit ?? 100, 500));
    const cid = encodeURIComponent(body.channel_id);
    const actionFilter = body.action?.trim()
      ? `&action=eq.${encodeURIComponent(body.action.trim())}`
      : "";
    const targetFilter = body.target_id?.trim()
      ? `&target_id=eq.${encodeURIComponent(body.target_id.trim())}`
      : "";

    const rows = await adminGet(
      `admin_audit_events?select=id,channel_id,actor_id,action,target_type,target_id,reason,event_payload_json,created_at&channel_id=eq.${cid}${actionFilter}${targetFilter}&order=created_at.desc&limit=${limit}`
    ) as Array<Record<string, unknown>>;

    return ok(rid, {
      channel_id: body.channel_id,
      count: rows.length,
      events: rows,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
