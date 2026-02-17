import { postEdge } from "./client";
import type {
  AdminDeleteOrderRequest,
  AdminOrdersListRequest,
  AdminUnassignDriverRequest,
  JsonRecord,
} from "./types";

export interface AdminOrdersListResponse {
  channel_id: string;
  count: number;
  orders: JsonRecord[];
}

export function adminOrdersList(
  request: AdminOrdersListRequest,
  authToken: string,
): Promise<AdminOrdersListResponse> {
  return postEdge<AdminOrdersListRequest, AdminOrdersListResponse>("admin-orders-list", request, {
    authToken,
  });
}

export function adminDeleteOrder(
  request: AdminDeleteOrderRequest,
  authToken: string,
): Promise<JsonRecord> {
  return postEdge<AdminDeleteOrderRequest, JsonRecord>("admin-delete-order", request, {
    authToken,
  });
}

export function adminUnassignDriver(
  request: AdminUnassignDriverRequest,
  authToken: string,
): Promise<JsonRecord> {
  return postEdge<AdminUnassignDriverRequest, JsonRecord>("admin-unassign-driver", request, {
    authToken,
  });
}
