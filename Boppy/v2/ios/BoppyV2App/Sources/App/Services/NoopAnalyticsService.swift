import Foundation
import BoppyV2Core

final class NoopAnalyticsService: AnalyticsServiceProtocol {
    func track(event: String, properties: [String : String]) {
        #if DEBUG
        print("[analytics] \(event) -> \(properties)")
        #endif
    }
}
