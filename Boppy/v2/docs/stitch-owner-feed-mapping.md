# Stitch Owner Feed Posting -> SwiftUI Mapping

This document maps raw Stitch exports in `v2/design/stitch/owner-feed-posting/` to BeamBox V2 SwiftUI implementation targets.

## Design Tokens (Baseline)

- Primary action: `#3C83F6`
- Dark background: `#101722`
- Dark surface: `#1E293B`
- Light background: `#F5F7F8`
- Card radius: `12`
- Chip radius: `999` (capsule)
- Spacing rhythm: `4 / 8 / 12 / 16 / 24`

## Screen Mapping

| Stitch Screen | Primary Goal | SwiftUI Target Files |
|---|---|---|
| `follower_channel_feed` | Feed header, invite-only badge, post cards | `v2/ios/BoppyV2App/Sources/App/Features/Feed/Components/FeedHeaderStrip.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Feed/Components/InviteOnlyBadge.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Feed/Components/FeedPostCard.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Feed/FeedView.swift` |
| `orders_management` | Owner inbox cards + status chips | `v2/ios/BoppyV2App/Sources/App/Features/Orders/Components/OrderInboxCard.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Orders/Components/OrderStatusPill.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Orders/OrdersView.swift` |
| `order_timeline` | Ledger chronology style | `v2/ios/BoppyV2App/Sources/App/Features/Orders/Components/LedgerTimelineView.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Orders/OrdersView.swift` |
| `assign_driver` | Driver assignment affordance in owner actions | `v2/ios/BoppyV2App/Sources/App/Features/Orders/OrdersView.swift` |
| `owner_route_planning` | Dispatch header, stop cards, reorder controls, action bar | `v2/ios/BoppyV2App/Sources/App/Features/Dispatch/Components/RouteSummaryHeader.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Dispatch/Components/RouteStopCard.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Dispatch/Components/DispatchActionBar.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Dispatch/DispatchView.swift` |
| `inventory_catalog` | V1.5 inventory entry card (UI placeholder) | `v2/ios/BoppyV2App/Sources/App/Features/Profile/Components/AdminPanelCard.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Profile/ProfileView.swift` |
| `admin_&_channels` | Admin/channels management entry card (UI placeholder) | `v2/ios/BoppyV2App/Sources/App/Features/Profile/Components/AdminPanelCard.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Profile/ProfileView.swift` |
| `add_item_with_price_variations` | V1.5 inventory SKU/variant capture reference | `v2/ios/BoppyV2App/Sources/App/Features/Profile/Components/AdminPanelCard.swift` (future flow link) |
| `follower_my_orders` | Follower order list visual treatment | `v2/ios/BoppyV2App/Sources/App/Features/Orders/Components/OrderInboxCard.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Orders/OrdersView.swift` |
| `follower_tiered_pricing_selection` | Tiered pricing selection UI (future order sheet enhancement) | `v2/ios/BoppyV2App/Sources/App/Components/OrderRequestSheet.swift` (future enhancement) |
| `sign_in_/_join_channel` | Auth and join-channel visual references | `v2/ios/BoppyV2App/Sources/App/Features/Auth/PhoneAuthView.swift`, `v2/ios/BoppyV2App/Sources/App/Features/Feed/FeedView.swift` |

## Implementation Boundaries

- `v2/design/stitch/owner-feed-posting/` remains raw reference only.
- Production runtime code must not import from raw design export paths.
- Convert only necessary visual patterns into feature-local SwiftUI components.
