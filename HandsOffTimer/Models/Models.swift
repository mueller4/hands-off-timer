import Foundation

struct ChainStep: Identifiable, Codable, Hashable {
    var id: UUID
    var label: String
    var durationSeconds: Int

    init(id: UUID = UUID(), label: String = "", durationSeconds: Int = 60) {
        self.id = id
        self.label = label
        self.durationSeconds = max(1, durationSeconds)
    }

    var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Step" : trimmed
    }

    func displayLabel(index: Int) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Step \(index + 1)" : trimmed
    }
}

struct TimerChain: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var steps: [ChainStep]
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        steps: [ChainStep] = [ChainStep(), ChainStep()],
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.steps = steps
        self.updatedAt = updatedAt
    }

    static let defaultName = "Untitled chain"
    static let minSteps = 2
    static let minStepSeconds = 1

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultName : trimmed
    }

    var totalSeconds: Int {
        steps.reduce(0) { $0 + max(0, $1.durationSeconds) }
    }

    var isSavable: Bool {
        steps.count >= Self.minSteps && steps.allSatisfy { $0.durationSeconds >= Self.minStepSeconds }
    }
}

enum EngineStatus: String, Codable {
    case idle
    case running
    case paused
    case completed
}

struct UpcomingEnd: Hashable {
    var stepIndex: Int
    var endDate: Date
    var label: String
}

struct EngineSnapshot: Hashable {
    var status: EngineStatus
    var sessionId: UUID?
    var chainId: UUID?
    var chainName: String
    var stepIndex: Int
    var stepCount: Int
    var label: String
    var nextLabel: String?
    var remaining: TimeInterval
    var endDate: Date?
    var totalRemaining: TimeInterval
    var upcomingEnds: [UpcomingEnd]

    static let idle = EngineSnapshot(
        status: .idle,
        sessionId: nil,
        chainId: nil,
        chainName: "",
        stepIndex: 0,
        stepCount: 0,
        label: "",
        nextLabel: nil,
        remaining: 0,
        endDate: nil,
        totalRemaining: 0,
        upcomingEnds: []
    )
}

struct NaturalEndEvent {
    var completedIndex: Int
    var completedLabel: String
    var nextIndex: Int?
    var nextLabel: String?
}
