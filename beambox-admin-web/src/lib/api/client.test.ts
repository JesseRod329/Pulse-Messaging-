import { afterEach, describe, expect, it, vi } from "vitest";
import { ApiClientError, postEdge } from "./client";

describe("postEdge", () => {
  const fetchMock = vi.fn<typeof fetch>();

  afterEach(() => {
    fetchMock.mockReset();
    vi.restoreAllMocks();
  });

  it("posts to the function endpoint and returns data", async () => {
    const envelope = {
      success: true,
      data: { ok: true },
      error: null,
      request_id: "req-1",
    };

    fetchMock.mockResolvedValue(
      new Response(JSON.stringify(envelope), {
        status: 200,
        headers: { "content-type": "application/json" },
      }),
    );

    vi.stubGlobal("fetch", fetchMock);

    const data = await postEdge("inventory-list", { channel_id: "abc" }, {
      authToken: "owner-token",
      baseUrl: "https://example.supabase.co/functions/v1",
    });

    expect(data).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(1);

    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe("https://example.supabase.co/functions/v1/inventory-list");
    expect(init.method).toBe("POST");

    const headers = init.headers as Record<string, string>;
    expect(headers.authorization).toBe("Bearer owner-token");
    expect(headers["content-type"]).toBe("application/json");
  });

  it("throws ApiClientError for envelope error", async () => {
    const envelope = {
      success: false,
      data: null,
      error: {
        code: "forbidden",
        message: "Forbidden",
      },
      request_id: "req-2",
    };

    fetchMock.mockResolvedValue(
      new Response(JSON.stringify(envelope), {
        status: 403,
        headers: { "content-type": "application/json" },
      }),
    );

    vi.stubGlobal("fetch", fetchMock);

    await expect(
      postEdge("admin-orders-list", { channel_id: "abc" }, {
        authToken: "driver-token",
        baseUrl: "https://example.supabase.co/functions/v1",
      }),
    ).rejects.toBeInstanceOf(ApiClientError);
  });
});
