import Foundation

/// Shared Home Screen widget state. Compiled into the app and the Home widget
/// extension. ChainEngine stays the source of truth; this file is the App Group
/// mirror the widget can read (idle catalog + wall-clock step ends).
enum HomeWidgetKind {
    static let id = "HandsOffTimerHome"
    static let appGroupID = "group.com.mueller4.HandsOffTimer"
    static let snapshotFilename = "home-widget.json"
    static let urlScheme = "handsofftimer"
}

enum HomeWidgetDestination: Equatable {
    /// Empty opens Home (New Chain when there are no chains). Idle opens the Home list.
    /// No per-chain highlight. Never starts a chain.
    case home(chainID: UUID?)
    /// Running. Same navigation as an Island tap. Does not pause, skip, or dismiss alarms.
    case run
}

enum HomeWidgetLink {
    static func url(for destination: HomeWidgetDestination) -> URL {
        var components = URLComponents()
        components.scheme = HomeWidgetKind.urlScheme
        switch destination {
        case .home(let chainID):
            components.host = "home"
            if let chainID {
                components.queryItems = [URLQueryItem(name: "chain", value: chainID.uuidString)]
            }
        case .run:
            components.host = "run"
        }
        return components.url ?? URL(string: "\(HomeWidgetKind.urlScheme)://home")!
    }

    static func destination(from url: URL) -> HomeWidgetDestination? {
        guard url.scheme?.lowercased() == HomeWidgetKind.urlScheme else { return nil }
        switch url.host?.lowercased() {
        case "run":
            return .run
        case "home":
            let chainID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "chain" }?
                .value
                .flatMap(UUID.init(uuidString:))
            return .home(chainID: chainID)
        default:
            return nil
        }
    }
}

struct HomeWidgetStep: Codable, Equatable, Hashable, Sendable {
    /// Raw label. Empty means the widget should say "Step N".
    var label: String
    var durationSeconds: Int

}

struct HomeWidgetChain: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: UUID
    /// Raw name. Empty displays as "Untitled chain".
    var name: String
    var steps: [HomeWidgetStep]
    var updatedAt: Date

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled chain" : trimmed
    }

    /// `{N} steps`, or a first-step duration only when the count is unknown.
    var stepCountText: String {
        if steps.isEmpty {
            return Formatters.duration(0)
        }
        return steps.count == 1 ? "1 step" : "\(steps.count) steps"
    }
}

struct HomeWidgetUpcoming: Codable, Equatable, Hashable, Sendable {
    var stepIndex: Int
    var endDate: Date
    var label: String
    var nextLabel: String?
    var nextDurationText: String?
}

/// One glance of a live or paused step. Countdown uses `endDate` (wall clock).
struct HomeWidgetRunDisplay: Equatable, Hashable, Sendable {
    var chainName: String
    var stepIndex: Int
    var stepCount: Int
    var label: String
    var nextLabel: String?
    var nextDurationText: String?
    var endDate: Date?
    var isPaused: Bool
    var remainingText: String

    var stepMeta: String {
        guard stepCount > 0 else { return "" }
        return "Step \(stepIndex + 1) of \(stepCount)"
    }

    /// Medium running footer. Last step has no next label.
    var nextLine: String {
        let next = nextLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if next.isEmpty { return "Last step" }
        if let nextDurationText, !nextDurationText.isEmpty {
            return "Next · \(next)  \(nextDurationText)"
        }
        return "Next · \(next)"
    }
}

struct HomeWidgetRun: Codable, Equatable, Hashable, Sendable {
    var chainID: UUID
    var chainName: String
    var stepIndex: Int
    var stepCount: Int
    var label: String
    var nextLabel: String?
    var nextDurationText: String?
    var endDate: Date?
    var isPaused: Bool
    var remainingText: String
    var upcoming: [HomeWidgetUpcoming]

    var currentDisplay: HomeWidgetRunDisplay {
        HomeWidgetRunDisplay(
            chainName: chainName,
            stepIndex: stepIndex,
            stepCount: stepCount,
            label: label,
            nextLabel: nextLabel,
            nextDurationText: nextDurationText,
            endDate: endDate,
            isPaused: isPaused,
            remainingText: remainingText
        )
    }

    func display(for step: HomeWidgetUpcoming) -> HomeWidgetRunDisplay {
        HomeWidgetRunDisplay(
            chainName: chainName,
            stepIndex: step.stepIndex,
            stepCount: stepCount,
            label: step.label,
            nextLabel: step.nextLabel,
            nextDurationText: step.nextDurationText,
            endDate: step.endDate,
            isPaused: false,
            remainingText: ""
        )
    }
}

enum HomeWidgetPhase: Equatable, Hashable, Sendable {
    case empty
    /// Last-started first, then most recently edited. At most three. Unique. No demo chains.
    case idle([HomeWidgetChain])
    case running(HomeWidgetRunDisplay)

    var destination: HomeWidgetDestination {
        switch self {
        case .empty, .idle:
            // Idle opens the Home list. It does not deep-link or highlight one chain.
            return .home(chainID: nil)
        case .running:
            return .run
        }
    }

    /// Small Idle speaks the first chain. Medium overrides this with every visible row.
    var accessibilityLabel: String {
        switch self {
        case .empty:
            return "No chains yet. Double-tap to open Hands-Off Timer."
        case .idle(let chains):
            guard let chain = chains.first else { return "Open to start." }
            return "\(chain.displayName), \(chain.stepCountText). Open to start."
        case .running(let run):
            let remaining = run.remainingText.isEmpty ? "time" : run.remainingText
            if run.isPaused {
                return "Paused, \(run.label), \(remaining) remaining. Opens run screen."
            }
            return "\(run.label), \(remaining) remaining. Opens run screen."
        }
    }

    var mediumIdleAccessibilityLabel: String {
        guard case .idle(let chains) = self, !chains.isEmpty else { return accessibilityLabel }
        let rows = chains.prefix(3).map { "\($0.displayName), \($0.stepCountText)" }.joined(separator: ". ")
        return "\(rows). Open to start."
    }
}

struct HomeWidgetDisk: Codable, Equatable, Sendable {
    var version: Int
    var chains: [HomeWidgetChain]
    var run: HomeWidgetRun?
    var lastStartedChainID: UUID?
    var lastStartedAt: Date?
    var lastSessionID: UUID?

    static let empty = HomeWidgetDisk(
        version: 1,
        chains: [],
        run: nil,
        lastStartedChainID: nil,
        lastStartedAt: nil,
        lastSessionID: nil
    )

    /// Most recently started chain, else most recently edited. No demo chain.
    func selectedChain() -> HomeWidgetChain? {
        if let id = lastStartedChainID, let match = chains.first(where: { $0.id == id }) {
            return match
        }
        return chains.sorted(by: Self.newerEdited).first
    }

    /// Last-started first, then the most recently edited others. Unique. Never pads with fake chains.
    func recentChains(limit: Int = 3) -> [HomeWidgetChain] {
        guard limit > 0 else { return [] }
        var ranked: [HomeWidgetChain] = []
        if let selected = selectedChain() {
            ranked.append(selected)
        }
        let rest = chains
            .filter { chain in !ranked.contains(where: { $0.id == chain.id }) }
            .sorted(by: Self.newerEdited)
        ranked.append(contentsOf: rest)
        return Array(ranked.prefix(limit))
    }

    func idlePhase() -> HomeWidgetPhase {
        let recent = recentChains(limit: 3)
        if recent.isEmpty { return .empty }
        return .idle(recent)
    }

    private static func newerEdited(_ lhs: HomeWidgetChain, _ rhs: HomeWidgetChain) -> Bool {
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    func signature() -> String {
        let chainSig = chains.map { chain in
            let steps = chain.steps.map { "\($0.label):\($0.durationSeconds)" }.joined(separator: ",")
            return "\(chain.id.uuidString)|\(chain.name)|\(Int(chain.updatedAt.timeIntervalSince1970))|\(steps)"
        }.joined(separator: ";")
        let runSig: String
        if let run {
            let ends = run.upcoming.map { "\($0.stepIndex)@\(Int($0.endDate.timeIntervalSince1970))" }.joined(separator: ",")
            let endBucket = Int((run.endDate ?? .distantPast).timeIntervalSince1970)
            runSig = [
                run.chainID.uuidString,
                run.isPaused ? "p" : "r",
                String(run.stepIndex),
                run.label,
                String(endBucket),
                ends,
            ].joined(separator: "|")
        } else {
            runSig = "none"
        }
        return [
            String(version),
            chainSig,
            lastStartedChainID?.uuidString ?? "",
            lastSessionID?.uuidString ?? "",
            runSig,
        ].joined(separator: "#")
    }

    static func load() -> HomeWidgetDisk? {
        guard let url = Self.fileURL(), let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HomeWidgetDisk.self, from: data)
    }

    @discardableResult
    func save() -> Bool {
        guard let url = HomeWidgetDisk.fileURL() else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func fileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: HomeWidgetKind.appGroupID)?
            .appendingPathComponent(HomeWidgetKind.snapshotFilename)
    }
}

struct HomeWidgetTimelineItem: Equatable, Sendable {
    var date: Date
    var phase: HomeWidgetPhase
}

enum HomeWidgetTimeline {
    struct Plan: Equatable, Sendable {
        var items: [HomeWidgetTimelineItem]
        /// `.atEnd` after the last precomputed step so a finished chain leaves Running without a ghost countdown.
        var reloadAtEnd: Bool
    }

    static func plan(disk: HomeWidgetDisk, now: Date) -> Plan {
        guard let run = disk.run else {
            return Plan(items: [HomeWidgetTimelineItem(date: now, phase: disk.idlePhase())], reloadAtEnd: false)
        }
        if run.isPaused {
            return Plan(
                items: [HomeWidgetTimelineItem(date: now, phase: .running(run.currentDisplay))],
                reloadAtEnd: false
            )
        }

        let future = run.upcoming.filter { $0.endDate > now }.sorted { $0.endDate < $1.endDate }
        if future.isEmpty {
            if let end = run.endDate, end > now {
                return Plan(
                    items: [
                        HomeWidgetTimelineItem(date: now, phase: .running(run.currentDisplay)),
                        HomeWidgetTimelineItem(date: end, phase: disk.idlePhase()),
                    ],
                    reloadAtEnd: true
                )
            }
            // Stop / complete / elapsed final step: Idle (or Empty). No leftover countdown.
            return Plan(items: [HomeWidgetTimelineItem(date: now, phase: disk.idlePhase())], reloadAtEnd: false)
        }

        var items: [HomeWidgetTimelineItem] = []
        for (offset, step) in future.enumerated() {
            let start = offset == 0 ? now : future[offset - 1].endDate
            var display = run.display(for: step)
            display.remainingText = Formatters.remaining(step.endDate.timeIntervalSince(start))
            items.append(HomeWidgetTimelineItem(date: start, phase: .running(display)))
        }
        if let last = future.last {
            items.append(HomeWidgetTimelineItem(date: last.endDate, phase: disk.idlePhase()))
        }
        return Plan(items: items, reloadAtEnd: true)
    }
}
