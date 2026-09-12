import Foundation

enum Formatters {
    static func duration(_ totalSeconds: Int) -> String {
        let safe = max(0, totalSeconds)
        let hours = safe / 3600
        let minutes = (safe % 3600) / 60
        let seconds = safe % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func remaining(_ interval: TimeInterval) -> String {
        duration(Int(ceil(max(0, interval))))
    }

    static func stepSummary(count: Int, totalSeconds: Int) -> String {
        let steps = count == 1 ? "1 step" : "\(count) steps"
        return "\(steps) · total \(duration(totalSeconds))"
    }
}
