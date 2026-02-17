const HARD_DELETE_TERMINAL_STATUSES = new Set(["cancelled", "delivered"]);

export function canHardDeleteStatus(status: string): boolean {
  return HARD_DELETE_TERMINAL_STATUSES.has(status);
}

