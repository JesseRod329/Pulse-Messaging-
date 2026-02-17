import { ApiHttpError } from "./http.ts";
import { adminRpc, SupabaseRequestError } from "./supabase.ts";

export async function appendLedger(
  orderId: string,
  actorId: string,
  eventType: string,
  payload: Record<string, unknown> = {},
): Promise<void> {
  try {
    await adminRpc("append_order_ledger_event", {
      p_order_id: orderId,
      p_actor_id: actorId,
      p_event_type: eventType,
      p_payload: payload,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      throw new ApiHttpError(500, "ledger_write_failed", error.message);
    }
    throw error;
  }
}
