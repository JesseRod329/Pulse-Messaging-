# BoppyV2App (iOS)

SwiftUI app shell for Boppy V2 using MVVM + Coordinator and role-based flows.

## What is implemented

- `AppCoordinator` as single navigation and workflow orchestrator
- Owner-only posting (text/image/video metadata)
- Follower long-press order request flow
- Owner order status + driver assignment flow
- Route build and stop completion flow
- Core routing fallback algorithm with tests

## Generate project

```bash
cd v2/ios/BoppyV2App
xcodegen generate
```

## Build + tests

```bash
cd v2/ios/BoppyV2App
swift test
xcodebuild -project BoppyV2App.xcodeproj -scheme BoppyV2App -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Config

Use `Config/xcconfig.template` to set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_EDGE_BASE_URL`.

- If values are real, app boots in **Live Cloud** mode (Supabase/Twilio/Mapbox-backed).
- If values are placeholders, app boots in **Local Demo** mode (in-memory backend + demo OTP `123456`).
