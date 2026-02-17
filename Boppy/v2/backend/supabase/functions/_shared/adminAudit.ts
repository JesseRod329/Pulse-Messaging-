import { ApiHttpError } from "./http.ts";
import { adminRpc, SupabaseRequestError } from "./supabase.ts";

export async function appendAdminAudit(
  channelId: string,
  actorId: string,
  action: string,
  targetType: string,
  targetId: string,
  reason: string | null,
  payload: Record<string, unknown> = {},
): Promise<void> {
  try {
    await adminRpc("log_admin_audit_event", {
      p_channel_id: channelId,
      p_actor_id: actorId,
      p_action: action,
      p_target_type: targetType,
      p_target_id: targetId,
      p_reason: reason,
      p_payload: payload,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      throw new ApiHttpError(500, "admin_audit_write_failed", error.message);
    }
    throw error;
  }
}
