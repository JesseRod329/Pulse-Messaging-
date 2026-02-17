import { postEdge } from "./client";
import type { InventoryAdjustStockRequest, InventoryListRequest, JsonRecord } from "./types";

export interface InventoryListResponse {
  channel_id: string;
  items: JsonRecord[];
  ledger: JsonRecord[];
}

export function inventoryList(
  request: InventoryListRequest,
  authToken: string,
): Promise<InventoryListResponse> {
  return postEdge<InventoryListRequest, InventoryListResponse>("inventory-list", request, {
    authToken,
  });
}

export function inventoryAdjustStock(
  request: InventoryAdjustStockRequest,
  authToken: string,
): Promise<JsonRecord> {
  return postEdge<InventoryAdjustStockRequest, JsonRecord>("inventory-adjust-stock", request, {
    authToken,
  });
}
