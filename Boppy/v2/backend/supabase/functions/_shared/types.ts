export type Role = "owner" | "driver" | "follower";

export interface ApiErrorShape {
  code: string;
  message: string;
}

export interface ApiEnvelope<T> {
  success: boolean;
  data: T | null;
  error: ApiErrorShape | null;
  request_id: string;
}

export interface AuthUser {
  id: string;
  phone?: string;
}

export type OrderStatus =
  | "requested"
  | "quoted"
  | "accepted"
  | "assigned"
  | "out_for_delivery"
  | "delivered"
  | "cancelled"
  | "address_review";
