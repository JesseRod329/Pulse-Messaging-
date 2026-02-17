import { useEffect, useMemo, useState } from "react";
import {
  adminArchiveChannel,
  adminAuditEventsList,
  adminChannelMembersList,
  adminDashboardSummary,
  adminDriverMembershipsUpsert,
  adminMemberRoleUpsert,
  adminRoutesList,
} from "./lib/api/admin";
import { ApiClientError } from "./lib/api/client";
import { inventoryAdjustStock, inventoryList } from "./lib/api/inventory";
import { adminDeleteOrder, adminOrdersList, adminUnassignDriver } from "./lib/api/orders";
import type { AppRole } from "./lib/api/types";

type Section = "orders" | "inventory" | "dispatch" | "channels" | "members" | "audit";

const SECTION_LABELS: Record<Section, string> = {
  orders: "Orders",
  inventory: "Stock",
  dispatch: "Delivery Routes",
  channels: "Channel Settings",
  members: "Team Members",
  audit: "Activity Log",
};

const SETTINGS_STORAGE_KEY = "beambox-admin-settings";

interface SavedSettings {
  channelId: string;
  authToken: string;
}

function readSavedSettings(): SavedSettings {
  try {
    const raw = localStorage.getItem(SETTINGS_STORAGE_KEY);
    if (!raw) return { channelId: "", authToken: "" };
    const parsed = JSON.parse(raw) as Partial<SavedSettings>;
    return {
      channelId: typeof parsed.channelId === "string" ? parsed.channelId : "",
      authToken: typeof parsed.authToken === "string" ? parsed.authToken : "",
    };
  } catch {
    return { channelId: "", authToken: "" };
  }
}

function makeClientError(error: unknown): ApiClientError {
  if (error instanceof ApiClientError) return error;
  if (error instanceof Error) {
    return new ApiClientError({
      status: 500,
      code: "runtime_error",
      message: error.message,
    });
  }
  return new ApiClientError({
    status: 500,
    code: "runtime_error",
    message: "Unexpected error",
  });
}

function valueAtPath(data: unknown, key: string): unknown {
  if (!data || typeof data !== "object") return null;
  return (data as Record<string, unknown>)[key] ?? null;
}

function summaryLines(data: unknown): string[] {
  const lines: string[] = [];

  const count = valueAtPath(data, "count");
  if (typeof count === "number") {
    lines.push(`Returned ${count} records.`);
  }

  const orders = valueAtPath(data, "orders");
  if (Array.isArray(orders)) {
    lines.push(`Orders in response: ${orders.length}.`);
  }

  const items = valueAtPath(data, "items");
  if (Array.isArray(items)) {
    lines.push(`Stock items in response: ${items.length}.`);
  }

  const routes = valueAtPath(data, "routes");
  if (Array.isArray(routes)) {
    lines.push(`Routes in response: ${routes.length}.`);
  }

  const members = valueAtPath(data, "members");
  if (Array.isArray(members)) {
    lines.push(`Members in response: ${members.length}.`);
  }

  const events = valueAtPath(data, "events");
  if (Array.isArray(events)) {
    lines.push(`Activity events in response: ${events.length}.`);
  }

  const mode = valueAtPath(data, "mode");
  if (typeof mode === "string") {
    lines.push(`Operation mode: ${mode}.`);
  }

  if (lines.length === 0 && data) {
    lines.push("Action completed successfully.");
  }

  return lines;
}

function App() {
  const defaults = useMemo(readSavedSettings, []);

  const [activeSection, setActiveSection] = useState<Section>("orders");
  const [channelId, setChannelId] = useState(defaults.channelId);
  const [authToken, setAuthToken] = useState(defaults.authToken);

  const [data, setData] = useState<unknown>(null);
  const [error, setError] = useState<ApiClientError | null>(null);
  const [busyAction, setBusyAction] = useState<string | null>(null);
  const [lastActionLabel, setLastActionLabel] = useState<string>("None yet");

  const [ordersLimit, setOrdersLimit] = useState("50");
  const [orderId, setOrderId] = useState("");
  const [deleteReason, setDeleteReason] = useState("Cleanup test order");
  const [hardDelete, setHardDelete] = useState(false);
  const [unassignReason, setUnassignReason] = useState("Driver unavailable");

  const [includeLedger, setIncludeLedger] = useState(false);
  const [itemId, setItemId] = useState("");
  const [variantId, setVariantId] = useState("");
  const [delta, setDelta] = useState("1");
  const [stockReason, setStockReason] = useState("Manual stock adjustment");

  const [routeStatus, setRouteStatus] = useState("");

  const [archiveReason, setArchiveReason] = useState("Channel archived by owner");

  const [membersLimit, setMembersLimit] = useState("100");
  const [memberUserId, setMemberUserId] = useState("");
  const [memberRole, setMemberRole] = useState<AppRole>("driver");
  const [memberReason, setMemberReason] = useState("Role update");
  const [driverOperation, setDriverOperation] = useState<"add" | "remove">("add");

  const [auditAction, setAuditAction] = useState("");
  const [auditTargetId, setAuditTargetId] = useState("");

  useEffect(() => {
    const next: SavedSettings = { channelId, authToken };
    localStorage.setItem(SETTINGS_STORAGE_KEY, JSON.stringify(next));
  }, [channelId, authToken]);

  function ensureConnected(): boolean {
    if (!channelId.trim()) {
      setError(
        new ApiClientError({
          status: 400,
          code: "channel_required",
          message: "Please enter the Workspace ID before running an action.",
        }),
      );
      return false;
    }

    if (!authToken.trim()) {
      setError(
        new ApiClientError({
          status: 401,
          code: "token_required",
          message: "Please paste the owner access token before running an action.",
        }),
      );
      return false;
    }

    return true;
  }

  async function runAction(label: string, action: () => Promise<unknown>) {
    if (!ensureConnected()) return;

    setBusyAction(label);
    setError(null);

    try {
      const result = await action();
      setData(result);
      setLastActionLabel(label);
    } catch (caught) {
      setError(makeClientError(caught));
    } finally {
      setBusyAction(null);
    }
  }

  function sectionButton(section: Section) {
    return (
      <button
        key={section}
        className={`tab-button ${activeSection === section ? "active" : ""}`}
        onClick={() => setActiveSection(section)}
        type="button"
      >
        {SECTION_LABELS[section]}
      </button>
    );
  }

  function renderQuickActions() {
    return (
      <div className="quick-grid">
        <button
          type="button"
          onClick={() =>
            runAction("Check overall channel health", () =>
              adminDashboardSummary({ channel_id: channelId }, authToken),
            )
          }
        >
          Check overall channel health
        </button>

        <button
          type="button"
          onClick={() =>
            runAction("Show recent orders", () =>
              adminOrdersList({ channel_id: channelId, limit: 25 }, authToken),
            )
          }
        >
          Show recent orders
        </button>

        <button
          type="button"
          onClick={() =>
            runAction("Show current stock", () =>
              inventoryList(
                {
                  channel_id: channelId,
                  include_inactive: false,
                  include_ledger: false,
                },
                authToken,
              ),
            )
          }
        >
          Show current stock
        </button>

        <button
          type="button"
          onClick={() =>
            runAction("Show delivery routes", () =>
              adminRoutesList({ channel_id: channelId, limit: 120 }, authToken),
            )
          }
        >
          Show delivery routes
        </button>

        <button
          type="button"
          onClick={() =>
            runAction("Show team members", () =>
              adminChannelMembersList({ channel_id: channelId, limit: 100 }, authToken),
            )
          }
        >
          Show team members
        </button>

        <button
          type="button"
          onClick={() =>
            runAction("Show recent activity", () =>
              adminAuditEventsList({ channel_id: channelId, limit: 50 }, authToken),
            )
          }
        >
          Show recent activity
        </button>
      </div>
    );
  }

  function renderOrders() {
    return (
      <>
        <p className="helper">Use this section for order lookups and order-level interventions.</p>

        <div className="row">
          <label>
            Number of recent orders
            <input value={ordersLimit} onChange={(event) => setOrdersLimit(event.target.value)} />
          </label>
          <button
            type="button"
            onClick={() =>
              runAction("Load recent orders", () =>
                adminOrdersList(
                  { channel_id: channelId, limit: Number(ordersLimit) || 50 },
                  authToken,
                ),
              )
            }
          >
            Load recent orders
          </button>
        </div>

        <details>
          <summary>Advanced order actions (only if needed)</summary>
          <div className="panel-subgrid details-grid">
            <label>
              Order ID
              <input value={orderId} onChange={(event) => setOrderId(event.target.value)} />
            </label>
            <label>
              Reason
              <input value={deleteReason} onChange={(event) => setDeleteReason(event.target.value)} />
            </label>
            <label className="checkbox">
              <input
                type="checkbox"
                checked={hardDelete}
                onChange={(event) => setHardDelete(event.target.checked)}
              />
              Permanently delete (irreversible)
            </label>
            <button
              type="button"
              onClick={() =>
                runAction("Delete or archive order", () =>
                  adminDeleteOrder(
                    {
                      order_id: orderId.trim(),
                      reason: deleteReason,
                      hard_delete: hardDelete,
                    },
                    authToken,
                  ),
                )
              }
            >
              Delete or archive order
            </button>
            <label>
              Unassign reason
              <input value={unassignReason} onChange={(event) => setUnassignReason(event.target.value)} />
            </label>
            <button
              type="button"
              onClick={() =>
                runAction("Unassign driver from order", () =>
                  adminUnassignDriver(
                    {
                      order_id: orderId.trim(),
                      reason: unassignReason,
                    },
                    authToken,
                  ),
                )
              }
            >
              Unassign driver
            </button>
          </div>
        </details>
      </>
    );
  }

  function renderInventory() {
    return (
      <>
        <p className="helper">Use this section for stock visibility and stock corrections.</p>

        <div className="row">
          <label className="checkbox">
            <input
              type="checkbox"
              checked={includeLedger}
              onChange={(event) => setIncludeLedger(event.target.checked)}
            />
            Include stock history
          </label>
          <button
            type="button"
            onClick={() =>
              runAction("Load stock list", () =>
                inventoryList(
                  {
                    channel_id: channelId,
                    include_inactive: false,
                    include_ledger: includeLedger,
                  },
                  authToken,
                ),
              )
            }
          >
            Load stock list
          </button>
        </div>

        <details>
          <summary>Advanced stock adjustment</summary>
          <div className="panel-subgrid details-grid">
            <label>
              Item ID
              <input value={itemId} onChange={(event) => setItemId(event.target.value)} />
            </label>
            <label>
              Variant ID (optional)
              <input value={variantId} onChange={(event) => setVariantId(event.target.value)} />
            </label>
            <label>
              Quantity change (+/-)
              <input value={delta} onChange={(event) => setDelta(event.target.value)} />
            </label>
            <label>
              Reason
              <input value={stockReason} onChange={(event) => setStockReason(event.target.value)} />
            </label>
            <button
              type="button"
              onClick={() =>
                runAction("Adjust stock", () =>
                  inventoryAdjustStock(
                    {
                      channel_id: channelId,
                      item_id: itemId.trim(),
                      variant_id: variantId.trim() || undefined,
                      delta: Number(delta) || 0,
                      reason: stockReason,
                    },
                    authToken,
                  ),
                )
              }
            >
              Adjust stock
            </button>
          </div>
        </details>
      </>
    );
  }

  function renderDispatch() {
    return (
      <>
        <p className="helper">Use this section to inspect routing status and stop progress.</p>
        <div className="panel-subgrid">
          <label>
            Status filter (optional)
            <input value={routeStatus} onChange={(event) => setRouteStatus(event.target.value)} />
          </label>
          <button
            type="button"
            onClick={() =>
              runAction("Load delivery routes", () =>
                adminRoutesList(
                  {
                    channel_id: channelId,
                    status: routeStatus.trim() || undefined,
                    limit: 120,
                  },
                  authToken,
                ),
              )
            }
          >
            Load delivery routes
          </button>
        </div>
      </>
    );
  }

  function renderChannels() {
    return (
      <>
        <p className="helper">Use this section for high-level channel checks and emergency archive action.</p>
        <div className="panel-subgrid">
          <button
            type="button"
            onClick={() =>
              runAction("Load dashboard summary", () =>
                adminDashboardSummary({ channel_id: channelId }, authToken),
              )
            }
          >
            Load dashboard summary
          </button>
          <label>
            Archive reason
            <input value={archiveReason} onChange={(event) => setArchiveReason(event.target.value)} />
          </label>
          <button
            type="button"
            onClick={() =>
              runAction("Archive channel", () =>
                adminArchiveChannel(
                  {
                    channel_id: channelId,
                    reason: archiveReason,
                  },
                  authToken,
                ),
              )
            }
          >
            Archive channel
          </button>
        </div>
      </>
    );
  }

  function renderMembers() {
    return (
      <>
        <p className="helper">Use this section for membership and role updates.</p>

        <div className="row">
          <label>
            Number of members
            <input value={membersLimit} onChange={(event) => setMembersLimit(event.target.value)} />
          </label>
          <button
            type="button"
            onClick={() =>
              runAction("Load members and invites", () =>
                adminChannelMembersList(
                  {
                    channel_id: channelId,
                    limit: Number(membersLimit) || 100,
                  },
                  authToken,
                ),
              )
            }
          >
            Load members and invites
          </button>
        </div>

        <details>
          <summary>Advanced member role tools</summary>
          <div className="panel-subgrid details-grid">
            <label>
              User ID
              <input value={memberUserId} onChange={(event) => setMemberUserId(event.target.value)} />
            </label>
            <label>
              Target role
              <select
                value={memberRole}
                onChange={(event) => setMemberRole(event.target.value as AppRole)}
              >
                <option value="driver">driver</option>
                <option value="follower">follower</option>
              </select>
            </label>
            <label>
              Reason
              <input value={memberReason} onChange={(event) => setMemberReason(event.target.value)} />
            </label>
            <button
              type="button"
              onClick={() =>
                runAction("Upsert member role", () =>
                  adminMemberRoleUpsert(
                    {
                      channel_id: channelId,
                      user_id: memberUserId.trim(),
                      role: memberRole === "owner" ? "driver" : memberRole,
                      reason: memberReason,
                    },
                    authToken,
                  ),
                )
              }
            >
              Update member role
            </button>

            <label>
              Driver operation
              <select
                value={driverOperation}
                onChange={(event) => setDriverOperation(event.target.value as "add" | "remove")}
              >
                <option value="add">add</option>
                <option value="remove">remove</option>
              </select>
            </label>
            <button
              type="button"
              onClick={() =>
                runAction("Update driver membership", () =>
                  adminDriverMembershipsUpsert(
                    {
                      channel_id: channelId,
                      driver_user_id: memberUserId.trim(),
                      operation: driverOperation,
                      reason: memberReason,
                    },
                    authToken,
                  ),
                )
              }
            >
              Update driver membership
            </button>
          </div>
        </details>
      </>
    );
  }

  function renderAudit() {
    return (
      <>
        <p className="helper">Use this section to inspect recent admin activity.</p>
        <div className="panel-subgrid">
          <label>
            Action filter (optional)
            <input value={auditAction} onChange={(event) => setAuditAction(event.target.value)} />
          </label>
          <label>
            Target ID filter (optional)
            <input value={auditTargetId} onChange={(event) => setAuditTargetId(event.target.value)} />
          </label>
          <button
            type="button"
            onClick={() =>
              runAction("Load activity log", () =>
                adminAuditEventsList(
                  {
                    channel_id: channelId,
                    action: auditAction.trim() || undefined,
                    target_id: auditTargetId.trim() || undefined,
                    limit: 100,
                  },
                  authToken,
                ),
              )
            }
          >
            Load activity log
          </button>
        </div>
      </>
    );
  }

  return (
    <main className="app-shell">
      <header className="hero">
        <p className="badge">BeamBox V2</p>
        <h1>Admin Helper Console</h1>
        <p className="subtitle">Simple workflow for daily operations, with advanced tools when needed.</p>
      </header>

      <section className="panel steps">
        <div className="panel-title">How To Use</div>
        <div className="steps-grid">
          <div className="step-card">
            <strong>Step 1:</strong> Enter Workspace ID and owner token.
          </div>
          <div className="step-card">
            <strong>Step 2:</strong> Use a quick action or choose a tab.
          </div>
          <div className="step-card">
            <strong>Step 3:</strong> Read the summary and open raw response if needed.
          </div>
        </div>
      </section>

      <section className="settings panel">
        <div className="panel-title">Connection</div>
        <p className="helper">These values are saved on this computer for convenience.</p>
        <div className="panel-subgrid">
          <label>
            Workspace ID (Channel ID)
            <input value={channelId} onChange={(event) => setChannelId(event.target.value)} />
          </label>
          <label>
            Owner access token
            <textarea
              value={authToken}
              onChange={(event) => setAuthToken(event.target.value)}
              rows={4}
              spellCheck={false}
            />
          </label>
          <button
            type="button"
            onClick={() =>
              runAction("Validate connection", () =>
                adminDashboardSummary({ channel_id: channelId }, authToken),
              )
            }
          >
            Validate connection
          </button>
        </div>
      </section>

      <section className="panel">
        <div className="panel-title">Quick Actions</div>
        {renderQuickActions()}
      </section>

      {error ? (
        <section className="panel error-panel" role="alert">
          <div className="panel-title">Action Failed</div>
          <p>
            <strong>{error.code}</strong>: {error.message}
          </p>
          {error.requestId ? <p>Request ID: {error.requestId}</p> : null}
          {error.isRateLimited ? (
            <p>
              Too many requests were sent. Wait a short moment, then retry the same action.
            </p>
          ) : null}
        </section>
      ) : null}

      <section className="panel">
        <div className="tabs">{(Object.keys(SECTION_LABELS) as Section[]).map(sectionButton)}</div>
        <div className="panel-title">{SECTION_LABELS[activeSection]}</div>
        <div className={`panel-body ${busyAction ? "busy" : ""}`}>
          {activeSection === "orders" ? renderOrders() : null}
          {activeSection === "inventory" ? renderInventory() : null}
          {activeSection === "dispatch" ? renderDispatch() : null}
          {activeSection === "channels" ? renderChannels() : null}
          {activeSection === "members" ? renderMembers() : null}
          {activeSection === "audit" ? renderAudit() : null}
        </div>
      </section>

      <section className="panel result-panel">
        <div className="panel-title">Latest Result</div>
        <p className="helper">
          Last action: <strong>{lastActionLabel}</strong>
        </p>
        {summaryLines(data).length > 0 ? (
          <ul className="result-summary">
            {summaryLines(data).map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        ) : (
          <p className="helper">No response yet. Run an action above.</p>
        )}

        <details>
          <summary>View raw response (advanced)</summary>
          <pre>{data ? JSON.stringify(data, null, 2) : "No response yet."}</pre>
        </details>
      </section>
    </main>
  );
}

export default App;
