import Foundation

@MainActor
@Observable
final class ChainStore {
    var chains: [TimerChain] = []

    private let url: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HandsOffTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("chains.json")
        load()
        #if DEBUG
        seedSampleChainsIfRequested()
        #endif
    }

    func upsert(_ chain: TimerChain) {
        var next = chain
        next.updatedAt = .now
        if let index = chains.firstIndex(where: { $0.id == next.id }) {
            chains[index] = next
        } else {
            chains.insert(next, at: 0)
        }
        save()
    }

    func delete(_ chain: TimerChain) {
        chains.removeAll { $0.id == chain.id }
        save()
    }

    func chain(id: UUID) -> TimerChain? {
        chains.first { $0.id == id }
    }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        struct Box: Codable { var version: Int; var chains: [TimerChain] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let box = try? decoder.decode(Box.self, from: data) {
            chains = box.chains
        }
    }

    #if DEBUG
    /// `-seedSampleChains` (Debug only): insert the sample chains into `chains.json`
    /// when the store is empty. The whole method is compiled out of Release.
    private func seedSampleChainsIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-seedSampleChains") else { return }
        guard chains.isEmpty else { return }
        // upsert inserts at index 0. Walk backward so Home (and -autoStartFirstChain)
        // starts with Pour-over coffee.
        for chain in Self.sampleChains().reversed() {
            upsert(chain)
        }
    }

    private static func sampleChains() -> [TimerChain] {
        [
            TimerChain(
                name: "Pour-over coffee",
                steps: [
                    ChainStep(label: "Bloom", durationSeconds: 45),
                    ChainStep(label: "Pour", durationSeconds: 90),
                    ChainStep(label: "Steep", durationSeconds: 120),
                ]
            ),
            TimerChain(
                name: "Interval run",
                steps: [
                    ChainStep(label: "Warm-up", durationSeconds: 5 * 60),
                    ChainStep(label: "Run", durationSeconds: 2 * 60),
                    ChainStep(label: "Walk", durationSeconds: 60),
                    ChainStep(label: "Run", durationSeconds: 2 * 60),
                    ChainStep(label: "Walk", durationSeconds: 60),
                ]
            ),
            TimerChain(
                name: "Desk stretch",
                steps: [
                    ChainStep(label: "Hamstrings", durationSeconds: 45),
                    ChainStep(label: "Quads", durationSeconds: 45),
                    ChainStep(label: "Shoulders", durationSeconds: 45),
                    ChainStep(label: "Calves", durationSeconds: 45),
                ]
            ),
        ]
    }
    #endif

    private func save() {
        struct Box: Codable { var version: Int; var chains: [TimerChain] }
        let box = Box(version: 1, chains: chains)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(box) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
