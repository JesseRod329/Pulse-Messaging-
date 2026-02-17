import type { OrderStatus } from "../_shared/types.ts";

const LEGAL_ASSIGNMENT_STATUSES = new Set<OrderStatus>(["accepted", "assigned", "address_review"]);

export function isLegalAssignmentStatus(status: OrderStatus): boolean {
  return LEGAL_ASSIGNMENT_STATUSES.has(status);
}

