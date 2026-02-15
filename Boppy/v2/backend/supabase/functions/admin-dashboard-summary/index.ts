import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { adminGet, SupabaseRequestError } from "../_shared/supabase.ts";

interface AdminDashboardSummaryBody {
  channel_id: string;
}

interface ChannelRow {
  id: string;
  title: string;
  is_active: boolean;
  created_at: string;
}

interface OrderRow {
  id: string;
  status: string;
  archived_at: string | null;
}

interface RouteRow {
  id: string;
  status: string;
}

interface InventoryRow {
  id: string;
  stock_on_hand: number;
  low_stock_threshold: number;
  is_active: boolean;
}

interface InviteRow {
  id: string;
  expires_at: string;
  max_uses: number | null;
  uses_count: number;
}

interface AuditRow {
  id: string;
  created_at: string;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminDashboardSummaryBody>(req);
    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");

    await requireChannelRole(body.channel_id, user.id, "owner");
    const cid = encodeURIComponent(body.channel_id);

    const channelRows = await adminGet(
      `channels?select=id,title,is_active,created_at&id=eq.${cid}&limit=1`,
    ) as ChannelRow[];
    const channel = channelRows[0];
    assert(channel, 404, "channel_not_found", "Channel not found.");

    const orders = await adminGet(
      `order_requests?select=id,status,archived_at&channel_id=eq.${cid}&limit=5000`,
    ) as OrderRow[];
    const routes = await adminGet(
      `delivery_routes?select=id,status&channel_id=eq.${cid}&limit=5000`,
    ) as RouteRow[];
    const inventory = await adminGet(
      `inventory_items?select=id,stock_on_hand,low_stock_threshold,is_active&channel_id=eq.${cid}&limit=5000`,
    ) as InventoryRow[];
    const invites = await adminGet(
      `channel_invites?select=id,expires_at,max_uses,uses_count&channel_id=eq.${cid}&limit=5000`,
    ) as InviteRow[];
    const audits = await adminGet(
      `admin_audit_events?select=id,created_at&channel_id=eq.${cid}&order=created_at.desc&limit=5000`,
    ) as AuditRow[];

    const orderCounts: Record<string, number> = {};
    for (const order of orders) {
      orderCounts[order.status] = (orderCounts[order.status] ?? 0) + 1;
    }

    const routeCounts: Record<string, number> = {};
    for (const route of routes) {
      routeCounts[route.status] = (routeCounts[route.status] ?? 0) + 1;
    }

    const lowStockCount = inventory.filter(
      (item) => item.is_active && item.stock_on_hand <= item.low_stock_threshold,
    ).length;

    const now = Date.now();
    const windowStart = now - 24 * 60 * 60 * 1000;
    const openInviteCount = invites.filter((invite) => {
      const expiresAt = new Date(invite.expires_at).getTime();
      const notExpired = Number.isFinite(expiresAt) && expiresAt > now;
      const hasUsesLeft =
        invite.max_uses == null ? true : invite.uses_count < invite.max_uses;
      return notExpired && hasUsesLeft;
    }).length;

    const auditLast24hCount = audits.filter((entry) => {
      const createdAt = new Date(entry.created_at).getTime();
      return Number.isFinite(createdAt) && createdAt >= windowStart;
    }).length;

    return ok(rid, {
      channel,
      orders: {
        total: orders.length,
        archived_count: orders.filter((order) => order.archived_at != null).length,
        by_status: orderCounts,
      },
      routes: {
        total: routes.length,
        by_status: routeCounts,
      },
      inventory: {
        total_items: inventory.length,
        low_stock_count: lowStockCount,
      },
      invites: {
        open_count: openInviteCount,
      },
      audits: {
        last_24h_count: auditLast24hCount,
      },
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
