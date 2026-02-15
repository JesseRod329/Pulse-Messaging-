import type { OrderStatus } from "../_shared/types.ts";

export const LEGAL_TRANSITIONS: Record<OrderStatus, ReadonlySet<OrderStatus>> = {
  requested: new Set(["quoted", "cancelled", "address_review"]),
  quoted: new Set(["accepted", "cancelled", "address_review"]),
  accepted: new Set(["assigned", "cancelled", "address_review"]),
  assigned: new Set(["out_for_delivery", "cancelled", "address_review"]),
  out_for_delivery: new Set(["delivered", "cancelled", "address_review"]),
  delivered: new Set(),
  cancelled: new Set(),
  address_review: new Set(["requested", "quoted", "accepted", "assigned", "cancelled"]),
};

export function canTransition(from: OrderStatus, to: OrderStatus): boolean {
  if (from == to) return true;
  return LEGAL_TRANSITIONS[from].has(to);
}
