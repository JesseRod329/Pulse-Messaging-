import { ApiHttpError, assert, onError, ok, readJson, requestId } from "../_shared/http.ts";
import { requireChannelRole, requireUser } from "../_shared/auth.ts";
import { adminGet, SupabaseRequestError } from "../_shared/supabase.ts";

interface AdminChannelMembersListBody {
  channel_id: string;
  role?: string;
  limit?: number;
}

interface MembershipRow {
  channel_id: string;
  user_id: string;
  role: string;
  joined_at: string;
}

interface ProfileRow {
  id: string;
  display_name: string | null;
  phone_e164: string;
  avatar_url: string | null;
  driver_availability: string | null;
  driver_rating: number | null;
  driver_trip_count: number | null;
  last_lat: number | null;
  last_lng: number | null;
}

Deno.serve(async (req) => {
  const rid = requestId(req);

  try {
    const user = await requireUser(req);
    const body = await readJson<AdminChannelMembersListBody>(req);
    assert(body.channel_id, 400, "invalid_request", "channel_id is required.");

    await requireChannelRole(body.channel_id, user.id, "owner");

    const limit = Math.max(1, Math.min(body.limit ?? 200, 500));
    const cid = encodeURIComponent(body.channel_id);
    const roleFilter = body.role?.trim()
      ? `&role=eq.${encodeURIComponent(body.role.trim())}`
      : "";

    const memberships = await adminGet(
      `channel_memberships?select=channel_id,user_id,role,joined_at&channel_id=eq.${cid}${roleFilter}&order=joined_at.desc&limit=${limit}`,
    ) as MembershipRow[];

    const uniqueUserIDs = [...new Set(memberships.map((membership) => membership.user_id))];
    const profilesByID = new Map<string, ProfileRow>();
    if (uniqueUserIDs.length > 0) {
      const userFilter = uniqueUserIDs.map((id) => encodeURIComponent(id)).join(",");
      const profiles = await adminGet(
        `profiles?select=id,display_name,phone_e164,avatar_url,driver_availability,driver_rating,driver_trip_count,last_lat,last_lng&id=in.(${userFilter})`,
      ) as ProfileRow[];
      for (const profile of profiles) {
        profilesByID.set(profile.id, profile);
      }
    }

    const invites = await adminGet(
      `channel_invites?select=id,token,expires_at,max_uses,uses_count,created_at&channel_id=eq.${cid}&order=created_at.desc&limit=100`,
    ) as Array<Record<string, unknown>>;

    const members = memberships.map((membership) => ({
      ...membership,
      profiles: profilesByID.get(membership.user_id)
        ? {
            display_name: profilesByID.get(membership.user_id)?.display_name ?? null,
            phone_e164: profilesByID.get(membership.user_id)?.phone_e164 ?? "",
            avatar_url: profilesByID.get(membership.user_id)?.avatar_url ?? null,
            driver_availability: profilesByID.get(membership.user_id)?.driver_availability ?? null,
            driver_rating: profilesByID.get(membership.user_id)?.driver_rating ?? null,
            driver_trip_count: profilesByID.get(membership.user_id)?.driver_trip_count ?? null,
            last_lat: profilesByID.get(membership.user_id)?.last_lat ?? null,
            last_lng: profilesByID.get(membership.user_id)?.last_lng ?? null,
          }
        : null,
    }));

    return ok(rid, {
      channel_id: body.channel_id,
      count: members.length,
      members,
      invites,
    });
  } catch (error) {
    if (error instanceof SupabaseRequestError) {
      return onError(rid, new ApiHttpError(500, "db_error", error.message));
    }
    return onError(rid, error);
  }
});
