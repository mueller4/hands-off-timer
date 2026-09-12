import Foundation

/// Owns chain progression via wall-clock deadlines.
/// Independent of AlarmKit and UserNotifications — alarms/notifications never gate auto-advance.
@MainActor
@Observable
final class ChainEngine {
    private(set) var snapshot: EngineSnapshot = .idle

    var onNaturalEnd: ((NaturalEndEvent) -> Void)?
    var onComplete: (() -> Void)?
    var onSnapshot: ((EngineSnapshot) -> Void)?

    private var session: Session?
    private var status: EngineStatus = .idle
    private var lastStepIndex = 0
    private var tickTask: Task<Void, Never>?
    private let persistURL: URL
    private let interval: TimeInterval

    private struct Session: Codable {
        var sessionId: UUID
        var chainId: UUID
        var chainName: String
        var steps: [ChainStep]
        var anchor: Date
        var pauseAccum: TimeInterval
        var pausedAt: Date?
        var skipBonus: TimeInterval
    }

    init(interval: TimeInterval = 0.05) {
        self.interval = interval
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HandsOffTimer", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        persistURL = dir.appendingPathComponent("active-run.json")
        restoreIfNeeded()
    }

    @discardableResult
    func start(chain: TimerChain, at now: Date = .now) -> EngineSnapshot {
        stopTicker()
        session = Session(
            sessionId: UUID(),
            chainId: chain.id,
            chainName: chain.displayName,
            steps: chain.steps,
            anchor: now,
            pauseAccum: 0,
            pausedAt: nil,
            skipBonus: 0
        )
        status = .running
        lastStepIndex = 0
        persist()
        startTicker()
        return publish(at: now)
    }

    @discardableResult
    func pause(at now: Date = .now) -> EngineSnapshot {
        guard var session, status == .running else { return snapshot }
        session.pausedAt = now
        self.session = session
        status = .paused
        stopTicker()
        persist()
        return publish(at: now)
    }

    @discardableResult
    func resume(at now: Date = .now) -> EngineSnapshot {
        guard var session, status == .paused else { return snapshot }
        session.pauseAccum += now.timeIntervalSince(session.pausedAt ?? now)
        session.pausedAt = nil
        self.session = session
        status = .running
        persist()
        startTicker()
        return publish(at: now)
    }

    /// Silent advance. Does not fire `onNaturalEnd`.
    @discardableResult
    func skip(at now: Date = .now) -> EngineSnapshot {
        guard session != nil, status == .running || status == .paused else { return snapshot }
        let progress = self.progress(at: now)
        if progress.complete { return complete(at: now) }
        session?.skipBonus += progress.remaining
        if status == .paused {
            session?.pausedAt = now
        }
        let next = self.progress(at: now)
        if next.complete { return complete(at: now) }
        lastStepIndex = next.stepIndex
        persist()
        return publish(at: now)
    }

    @discardableResult
    func stop() -> EngineSnapshot {
        stopTicker()
        session = nil
        status = .idle
        lastStepIndex = 0
        clearPersist()
        snapshot = .idle
        onSnapshot?(snapshot)
        return snapshot
    }

    @discardableResult
    func acknowledgeComplete() -> EngineSnapshot {
        stop()
    }

    @discardableResult
    func tick(at now: Date = .now) -> EngineSnapshot {
        guard session != nil, status == .running else { return snapshot }
        let progress = self.progress(at: now)
        if progress.complete {
            if let session {
                let completed = session.steps[safe: lastStepIndex]
                onNaturalEnd?(
                    NaturalEndEvent(
                        completedIndex: lastStepIndex,
                        completedLabel: completed?.displayLabel(index: lastStepIndex) ?? "",
                        nextIndex: nil,
                        nextLabel: nil
                    )
                )
            }
            return complete(at: now)
        }
        if progress.stepIndex > lastStepIndex, let session {
            for i in lastStepIndex..<progress.stepIndex {
                let completed = session.steps[safe: i]
                let next = session.steps[safe: i + 1]
                onNaturalEnd?(
                    NaturalEndEvent(
                        completedIndex: i,
                        completedLabel: completed?.displayLabel(index: i) ?? "",
                        nextIndex: next == nil ? nil : i + 1,
                        nextLabel: next?.displayLabel(index: i + 1)
                    )
                )
            }
            lastStepIndex = progress.stepIndex
        }
        persist()
        return publish(at: now)
    }

    // MARK: - Internals

    private func complete(at now: Date) -> EngineSnapshot {
        status = .completed
        stopTicker()
        if let session {
            lastStepIndex = max(0, session.steps.count - 1)
        }
        clearPersist()
        let snap = publish(at: now)
        onComplete?()
        return snap
    }

    private func elapsed(at now: Date) -> TimeInterval {
        guard let session else { return 0 }
        let end = session.pausedAt ?? now
        return max(0, end.timeIntervalSince(session.anchor) - session.pauseAccum + session.skipBonus)
    }

    private struct Progress {
        var complete: Bool
        var stepIndex: Int
        var remaining: TimeInterval
    }

    private func progress(at now: Date) -> Progress {
        guard let session else {
            return Progress(complete: true, stepIndex: 0, remaining: 0)
        }
        var budget = elapsed(at: now)
        for (i, step) in session.steps.enumerated() {
            let dur = TimeInterval(max(0, step.durationSeconds))
            if budget < dur {
                return Progress(complete: false, stepIndex: i, remaining: dur - budget)
            }
            budget -= dur
        }
        return Progress(complete: true, stepIndex: session.steps.count, remaining: 0)
    }

    private func totalRemaining(at now: Date) -> TimeInterval {
        guard let session, status != .completed else { return 0 }
        let progress = progress(at: now)
        if progress.complete { return 0 }
        var total = progress.remaining
        if progress.stepIndex + 1 < session.steps.count {
            for step in session.steps[(progress.stepIndex + 1)...] {
                total += TimeInterval(step.durationSeconds)
            }
        }
        return total
    }

    private func upcomingEnds(at now: Date) -> [UpcomingEnd] {
        guard let session, status == .running else { return [] }
        let progress = progress(at: now)
        if progress.complete { return [] }
        var ends: [UpcomingEnd] = []
        var cursor = now.addingTimeInterval(progress.remaining)
        ends.append(
            UpcomingEnd(
                stepIndex: progress.stepIndex,
                endDate: cursor,
                label: session.steps[progress.stepIndex].displayLabel(index: progress.stepIndex)
            )
        )
        if progress.stepIndex + 1 < session.steps.count {
            for i in (progress.stepIndex + 1)..<session.steps.count {
                cursor = cursor.addingTimeInterval(TimeInterval(session.steps[i].durationSeconds))
                ends.append(
                    UpcomingEnd(
                        stepIndex: i,
                        endDate: cursor,
                        label: session.steps[i].displayLabel(index: i)
                    )
                )
            }
        }
        return ends
    }

    @discardableResult
    private func publish(at now: Date) -> EngineSnapshot {
        guard let session else {
            snapshot = .idle
            onSnapshot?(snapshot)
            return snapshot
        }
        let progress = progress(at: now)
        let stepIndex = progress.complete ? max(0, session.steps.count - 1) : progress.stepIndex
        let step = session.steps[safe: stepIndex]
        let next = progress.complete ? nil : session.steps[safe: stepIndex + 1]
        let remaining = status == .completed ? 0 : progress.remaining
        snapshot = EngineSnapshot(
            status: status,
            sessionId: session.sessionId,
            chainId: session.chainId,
            chainName: session.chainName,
            stepIndex: stepIndex,
            stepCount: session.steps.count,
            label: step?.displayLabel(index: stepIndex) ?? "",
            nextLabel: next?.displayLabel(index: stepIndex + 1),
            remaining: remaining,
            endDate: (status == .running && !progress.complete) ? now.addingTimeInterval(remaining) : nil,
            totalRemaining: totalRemaining(at: now),
            upcomingEnds: upcomingEnds(at: now)
        )
        onSnapshot?(snapshot)
        return snapshot
    }

    private func startTicker() {
        stopTicker()
        let interval = self.interval
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }
                self?.tick()
            }
        }
    }

    private func stopTicker() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func persist() {
        guard let session, status == .running || status == .paused else { return }
        struct Box: Codable {
            var session: Session
            var status: EngineStatus
            var lastStepIndex: Int
        }
        let box = Box(session: session, status: status, lastStepIndex: lastStepIndex)
        if let data = try? JSONEncoder().encode(box) {
            try? data.write(to: persistURL, options: .atomic)
        }
    }

    private func clearPersist() {
        try? FileManager.default.removeItem(at: persistURL)
    }

    private func restoreIfNeeded() {
        struct Box: Codable {
            var session: Session
            var status: EngineStatus
            var lastStepIndex: Int
        }
        guard let data = try? Data(contentsOf: persistURL),
              let box = try? JSONDecoder().decode(Box.self, from: data)
        else { return }
        session = box.session
        status = box.status
        lastStepIndex = box.lastStepIndex
        let now = Date.now
        if box.status == .paused {
            snapshot = publish(at: now)
            return
        }
        status = .running
        let progress = progress(at: now)
        if progress.complete {
            clearPersist()
            session = nil
            status = .idle
            snapshot = .idle
            return
        }
        lastStepIndex = progress.stepIndex
        startTicker()
        snapshot = publish(at: now)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
