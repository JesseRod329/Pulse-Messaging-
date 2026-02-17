import { postEdge } from "./client";
import type {
  AdminArchiveChannelRequest,
  AdminAuditEventsListRequest,
  AdminChannelMembersListRequest,
  AdminDashboardSummaryRequest,
  AdminDriverMembershipsUpsertRequest,
  AdminMemberRoleUpsertRequest,
  AdminRoutesListRequest,
  JsonRecord,
} from "./types";

export interface AdminRoutesListResponse {
  channel_id: string;
  count: number;
  routes: JsonRecord[];
}

export interface AdminChannelMembersListResponse {
  channel_id: string;
  count: number;
  members: JsonRecord[];
  invites: JsonRecord[];
}

export interface AdminAuditEventsListResponse {
  channel_id: string;
  count: number;
  events: JsonRecord[];
}

export function adminRoutesList(
  request: AdminRoutesListRequest,
  authToken: string,
): Promise<AdminRoutesListResponse> {
  return postEdge<AdminRoutesListRequest, AdminRoutesListResponse>("admin-routes-list", request, {
    authToken,
  });
}

export function adminChannelMembersList(
  request: AdminChannelMembersListRequest,
  authToken: string,
): Promise<AdminChannelMembersListResponse> {
  return postEdge<AdminChannelMembersListRequest, AdminChannelMembersListResponse>(
    "admin-channel-members-list",
    request,
    { authToken },
  );
}

export function adminAuditEventsList(
  request: AdminAuditEventsListRequest,
  authToken: string,
): Promise<AdminAuditEventsListResponse> {
  return postEdge<AdminAuditEventsListRequest, AdminAuditEventsListResponse>(
    "admin-audit-events-list",
    request,
    { authToken },
  );
}

export function adminArchiveChannel(
  request: AdminArchiveChannelRequest,
  authToken: string,
): Promise<JsonRecord> {
  return postEdge<AdminArchiveChannelRequest, JsonRecord>("admin-archive-channel", request, {
    authToken,
  });
}

export function adminDashboardSummary(
  request: AdminDashboardSummaryRequest,
  authToken: string,
): Promise<JsonRecord> {
  return postEdge<AdminDashboardSummaryRequest, JsonRecord>("admin-dashboard-summary", request, {
    authToken,
  });
}

export function adminDriverMembershipsUpsert(
  request: AdminDriverMembershipsUpsertRequest,
  authToken: string,
): Promise<JsonRecord> {
  return postEdge<AdminDriverMembershipsUpsertRequest, JsonRecord>(
    "admin-driver-memberships-upsert",
    request,
    { authToken },
  );
}

export function adminMemberRoleUpsert(
  request: AdminMemberRoleUpsertRequest,
  authToken: string,
): Promise<JsonRecord> {
  return postEdge<AdminMemberRoleUpsertRequest, JsonRecord>("admin-member-role-upsert", request, {
    authToken,
  });
}
