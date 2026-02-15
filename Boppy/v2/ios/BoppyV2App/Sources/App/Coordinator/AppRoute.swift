import Foundation

enum AppRoute: Hashable {
    case auth
    case main
    case feed
    case orders
    case dispatch
    case profile
    case channel(channelID: String)
    case orderDetails(orderID: String)
    case orderSheet(postID: String)
    case inviteJoin(token: String)
}

enum MainTab: Hashable {
    case feed
    case orders
    case dispatch
    case profile
}
