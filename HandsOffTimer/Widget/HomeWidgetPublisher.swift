import Foundation
import os
import WidgetKit

/// Writes the App Group snapshot from ChainStore + EngineSnapshot and reloads
/// the Home Screen widget. Does not import AlarmKit and does not touch the engine.
@MainActor
enum HomeWidgetPublisher {
    private static var cached = HomeWidgetDisk.empty
    private static var didLoad = false
    private static var lastSignature = ""
    private static var didLogMissingGroup = false
    private static let logger = Logger(subsystem: "com.mueller4.HandsOffTimer", category: "HomeWidget")

    static func publish(chains: [TimerChain], snapshot: EngineSnapshot) {
        if !didLoad {
            cached = HomeWidgetDisk.load() ?? .empty
            didLoad = true
            lastSignature = cached.signature()
        }
        var disk = cached
        disk.version = 1
        disk.chains = chains.map { HomeWidgetChain(chain: $0) }

        if disk.lastStartedChainID != nil,
           !disk.chains.contains(where: { $0.id == disk.lastStartedChainID }) {
            disk.lastStartedChainID = nil
            disk.lastStartedAt = nil
        }

        switch snapshot.status {
        case .running, .paused:
            if let sessionID = snapshot.sessionId, sessionID != disk.lastSessionID {
                disk.lastSessionID = sessionID
                if let chainID = snapshot.chainId {
                    disk.lastStartedChainID = chainID
                    disk.lastStartedAt = Date()
                }
            }
            disk.run = HomeWidgetRun.make(snapshot: snapshot, chains: disk.chains)
        case .idle, .completed:
            disk.run = nil
        }

        let signature = disk.signature()
        guard signature != lastSignature else { return }
        guard disk.save() else {
            logMissingGroupIfNeeded()
            return
        }
        lastSignature = signature
        cached = disk
        WidgetCenter.shared.reloadTimelines(ofKind: HomeWidgetKind.id)
    }

    private static func logMissingGroupIfNeeded() {
        guard HomeWidgetDisk.fileURL() == nil, !didLogMissingGroup else { return }
        didLogMissingGroup = true
        logger.error("App Group \(HomeWidgetKind.appGroupID, privacy: .public) is unavailable. Enable it for the app and Home widget in Xcode / the developer portal.")
    }
}

private extension HomeWidgetChain {
    init(chain: TimerChain) {
        self.init(
            id: chain.id,
            name: chain.name,
            steps: chain.steps.map { HomeWidgetStep(label: $0.label, durationSeconds: $0.durationSeconds) },
            updatedAt: chain.updatedAt
        )
    }
}

private extension HomeWidgetRun {
    static func make(snapshot: EngineSnapshot, chains: [HomeWidgetChain]) -> HomeWidgetRun? {
        guard snapshot.status == .running || snapshot.status == .paused else { return nil }
        guard let chainID = snapshot.chainId else { return nil }
        let chain = chains.first { $0.id == chainID }
        let chainName = snapshot.chainName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (chain?.displayName ?? "Untitled chain")
            : snapshot.chainName

        func durationText(at index: Int) -> String? {
            guard let chain, chain.steps.indices.contains(index) else { return nil }
            return Formatters.duration(chain.steps[index].durationSeconds)
        }

        let upcoming: [HomeWidgetUpcoming]
        if snapshot.status == .running {
            upcoming = snapshot.upcomingEnds.map { end in
                let nextIndex = end.stepIndex + 1
                let next = snapshot.upcomingEnds.first { $0.stepIndex == nextIndex }
                return HomeWidgetUpcoming(
                    stepIndex: end.stepIndex,
                    endDate: end.endDate,
                    label: end.label,
                    nextLabel: next?.label,
                    nextDurationText: next == nil ? nil : durationText(at: nextIndex)
                )
            }
        } else {
            upcoming = []
        }

        let nextIndex = snapshot.stepIndex + 1
        let nextDuration = snapshot.nextLabel == nil ? nil : durationText(at: nextIndex)
        return HomeWidgetRun(
            chainID: chainID,
            chainName: chainName,
            stepIndex: snapshot.stepIndex,
            stepCount: snapshot.stepCount,
            label: snapshot.label,
            nextLabel: snapshot.nextLabel,
            nextDurationText: nextDuration,
            endDate: snapshot.endDate,
            isPaused: snapshot.status == .paused,
            remainingText: Formatters.remaining(snapshot.remaining),
            upcoming: upcoming
        )
    }
}
