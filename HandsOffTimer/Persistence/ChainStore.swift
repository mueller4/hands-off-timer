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
