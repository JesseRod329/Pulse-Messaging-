export type AppRole = "owner" | "driver" | "follower";

export interface ApiErrorPayload {
  code: string;
  message: string;
}

export interface ApiEnvelope<T> {
  success: boolean;
  data: T | null;
  error: ApiErrorPayload | null;
  request_id: string;
}

export interface InventoryListRequest {
  channel_id: string;
  include_inactive?: boolean;
  include_ledger?: boolean;
}

export interface InventoryAdjustStockRequest {
  channel_id: string;
  item_id: string;
  variant_id?: string;
  delta: number;
  reason: string;
}

export interface AdminOrdersListRequest {
  channel_id: string;
  status?: string;
  limit?: number;
  include_archived?: boolean;
}

export interface AdminDeleteOrderRequest {
  order_id: string;
  reason: string;
  hard_delete?: boolean;
}

export interface AdminUnassignDriverRequest {
  order_id: string;
  reason: string;
}

export interface AdminRoutesListRequest {
  channel_id: string;
  status?: string;
  limit?: number;
}

export interface AdminChannelMembersListRequest {
  channel_id: string;
  role?: string;
  limit?: number;
}

export interface AdminAuditEventsListRequest {
  channel_id: string;
  action?: string;
  target_id?: string;
  limit?: number;
}

export interface AdminArchiveChannelRequest {
  channel_id: string;
  reason: string;
}

export interface AdminDriverMembershipsUpsertRequest {
  channel_id: string;
  driver_user_id: string;
  operation: "add" | "remove";
  reason: string;
}

export interface AdminMemberRoleUpsertRequest {
  channel_id: string;
  user_id: string;
  role: "driver" | "follower";
  reason: string;
}

export interface AdminDashboardSummaryRequest {
  channel_id: string;
}

export type JsonRecord = Record<string, unknown>;
