export function canCompleteStop(
  isOwner: boolean,
  isAssignedDriver: boolean,
): boolean {
  return isOwner || isAssignedDriver;
}

export function nextRouteStatus(
  currentStatus: string,
  remainingStops: number,
): "completed" | "in_progress" | null {
  if (remainingStops === 0) return "completed";
  if (currentStatus === "planned") return "in_progress";
  return null;
}

