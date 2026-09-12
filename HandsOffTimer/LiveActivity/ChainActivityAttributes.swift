import ActivityKit
import Foundation

struct ChainActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stepIndex: Int
        var stepCount: Int
        var label: String
        var endDate: Date
        var nextLabel: String
        var isPaused: Bool
    }

    var chainName: String
}
