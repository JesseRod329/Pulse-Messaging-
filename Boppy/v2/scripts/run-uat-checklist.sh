#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADMIN_WEB_DIR="$(cd "$ROOT_DIR/../../beambox-admin-web" && pwd)"
IOS_DIR="$ROOT_DIR/ios/BoppyV2App"
FUNCTIONS_DIR="$ROOT_DIR/backend/supabase/functions"
RLS_SCRIPT="$ROOT_DIR/backend/supabase/scripts/rls-matrix-check.ts"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

run_check() {
  local label="$1"
  shift
  echo ""
  echo "==> $label"
  if "$@"; then
    echo "PASS: $label"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $label"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

skip_check() {
  local label="$1"
  local reason="$2"
  echo ""
  echo "==> $label"
  echo "SKIP: $reason"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

echo "BeamBox V2 UAT Checklist Runner"
echo "Root: $ROOT_DIR"

run_check "Admin web typecheck" bash -lc "cd '$ADMIN_WEB_DIR' && npm run typecheck"
run_check "Admin web tests" bash -lc "cd '$ADMIN_WEB_DIR' && npm test"

run_check "iOS build" bash -lc "cd '$IOS_DIR' && swift build"
run_check "iOS tests" bash -lc "cd '$IOS_DIR' && swift test"

run_check "Edge function typecheck" bash -lc "cd '$FUNCTIONS_DIR' && deno check --config deno.json _shared/rateLimit.ts update-order-status/transitions.ts update-order-status/index.ts"
run_check "Edge function unit tests" bash -lc "cd '$ROOT_DIR' && SUPABASE_URL='http://localhost:54321' SUPABASE_SERVICE_ROLE_KEY='dev-key' SUPABASE_ANON_KEY='anon-dev' deno test --allow-env=SUPABASE_URL,SUPABASE_SERVICE_ROLE_KEY,SUPABASE_ANON_KEY --config '$FUNCTIONS_DIR/deno.json' '$FUNCTIONS_DIR/update-order-status/transitions_test.ts' '$FUNCTIONS_DIR/_shared/rateLimit_test.ts'"

if [[ -n "${RLS_CHANNEL_ID:-}" && -n "${RLS_OWNER_TOKEN:-}" && -n "${RLS_DRIVER_TOKEN:-}" && -n "${RLS_FOLLOWER_TOKEN:-}" ]]; then
  run_check "Live RLS matrix" bash -lc "cd '$ROOT_DIR' && SUPABASE_URL='${SUPABASE_URL:-}' SUPABASE_FUNCTIONS_BASE_URL='${SUPABASE_FUNCTIONS_BASE_URL:-}' RLS_CHANNEL_ID='$RLS_CHANNEL_ID' RLS_OWNER_TOKEN='$RLS_OWNER_TOKEN' RLS_DRIVER_TOKEN='$RLS_DRIVER_TOKEN' RLS_FOLLOWER_TOKEN='$RLS_FOLLOWER_TOKEN' deno run --allow-env --allow-net '$RLS_SCRIPT'"
else
  skip_check "Live RLS matrix" "Set RLS_CHANNEL_ID + RLS_OWNER_TOKEN + RLS_DRIVER_TOKEN + RLS_FOLLOWER_TOKEN to enable this check."
fi

echo ""
echo "UAT Summary"
echo "-----------"
echo "Passed:  $PASS_COUNT"
echo "Failed:  $FAIL_COUNT"
echo "Skipped: $SKIP_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi

exit 0
