import ActivityKit
import Foundation

struct ChainActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stepIndex: Int
        var stepCount: Int
        var label: String
        /// Wall-clock step-end. Always in the future while running so
        /// `Text(endDate, style: .timer)` has a non-empty countdown.
        var endDate: Date
        /// Frozen mm:ss for pause (and a non-timer fallback).
        var remainingText: String
        var nextLabel: String
        var isPaused: Bool
    }

    var chainName: String
}
