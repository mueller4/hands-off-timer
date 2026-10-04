import AlarmKit
import Foundation
import os
import SwiftUI

/// Schedules AlarmKit step-end alarms from engine snapshots.
/// Never pauses, stops, resets, or delays the chain — ChainEngine is independent.
@MainActor
final class AlarmKitGateway {
    static let shared = AlarmKitGateway()

    static let purpose =
        "Hands-Off Timer uses alarms so each step can break through Silent and Focus when it ends. The next timer is already running — acknowledge when you’re ready."

    private let manager = AlarmManager.shared
    private let logger = Logger(subsystem: "com.mueller4.HandsOffTimer", category: "AlarmKit")
    private static let retryDelay: TimeInterval = 2

    /// Not-yet-fired schedules, keyed by engine step index.
    private var pendingByStep: [Int: Pending] = [:]
    /// Alarm id to engine step, kept after the id leaves `pendingByStep` so OK can
    /// remember the step even if reconcile already promoted it.
    private var stepIndexByAlarmID: [UUID: Int] = [:]
    /// Steps the user already acknowledged. `noteNaturalEnd` must not catch these up.
    private var acknowledgedSteps: Set<Int> = []
    /// Step-end alarms that are alerting (or catch-up alarms about to alert). Never cancel/stop these except OK or Stop.
    private var alertingIDs: Set<UUID> = []
    /// Natural ends that had no pending schedule (in-process catch-up). Flushed on the next apply.
    private var catchUpLabels: [String] = []
    private var lastSignature = ""
    private var retrySignature: String?
    private var retryAfter: Date?
    private var nextCatchUpAttempt: Date?

    /// Latest snapshot wins. Older queued snapshots are dropped.
    private var latestSnapshot: EngineSnapshot?
    private var latestGeneration: UInt64 = 0
    /// Generation of the most recent Stop / new Start teardown. In-flight applies older than this must not reschedule.
    private var tornDownGeneration: UInt64 = 0
    private var applyTask: Task<Void, Never>?

    private struct Pending {
        var stepIndex: Int
        var endDate: Date
        var id: UUID
    }

    private init() {}

    var needsAuthorizationPrompt: Bool {
        manager.authorizationState == .notDetermined
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        switch manager.authorizationState {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await manager.requestAuthorization()) == .authorized
        @unknown default:
            return (try? await manager.requestAuthorization()) == .authorized
        }
    }

    /// Call from `onNaturalEnd` before snapshot sync so the firing alarm is not cancelled.
    /// If this end had no pending schedule (catch-up / missed middle step), queue an
    /// acknowledge-required alarm — engine already advanced; this is output-only.
    /// Ends the user already acknowledged are ignored so OK-before-tick cannot schedule a second alarm.
    func noteNaturalEnd(_ event: NaturalEndEvent) {
        if acknowledgedSteps.contains(event.completedIndex) {
            if let pending = pendingByStep.removeValue(forKey: event.completedIndex) {
                stepIndexByAlarmID.removeValue(forKey: pending.id)
            }
            return
        }
        if let pending = pendingByStep[event.completedIndex] {
            alertingIDs.insert(pending.id)
            remember(step: event.completedIndex, alarmID: pending.id)
            pendingByStep.removeValue(forKey: event.completedIndex)
            return
        }
        catchUpLabels.append(event.completedLabel)
    }

    /// OK / stop intent ran. Bookkeeping only — the intent already stopped the alarm.
    /// Must never pause, stop, skip, or reschedule ChainEngine.
    func noteAcknowledged(id: UUID) {
        alertingIDs.remove(id)
        let step = stepIndexByAlarmID[id] ?? pendingByStep.first { $0.value.id == id }?.key
        if let step, step >= 0 {
            acknowledgedSteps.insert(step)
        }
        pendingByStep = pendingByStep.filter { $0.value.id != id }
        stepIndexByAlarmID.removeValue(forKey: id)
    }

    /// Stop, or Home Start of a new chain. Cancel scheduled + alerting alarms
    /// for the prior run. Does not touch ChainEngine.
    /// Bumps the generation so an in-flight apply cannot reschedule after this returns.
    func cancelAllForRun() {
        latestGeneration &+= 1
        tornDownGeneration = latestGeneration
        latestSnapshot = nil
        tearDownAll()
    }

    func sync(_ snapshot: EngineSnapshot) {
        let signature = signature(of: snapshot)
        let needsCatchUp = !catchUpLabels.isEmpty && !isCatchUpBackedOff
        let needsSchedule = signature != lastSignature && !shouldDeferScheduleRetry(signature)
        // Steady-state ticks share a signature. Leave any in-flight apply alone.
        guard needsCatchUp || needsSchedule else { return }
        latestGeneration &+= 1
        latestSnapshot = snapshot
        guard applyTask == nil else { return }
        applyTask = Task { await drainApplies() }
    }

    private func drainApplies() async {
        defer { applyTask = nil }
        while let snapshot = latestSnapshot {
            let generation = latestGeneration
            latestSnapshot = nil
            await apply(snapshot, generation: generation)
        }
    }

    private func apply(_ snapshot: EngineSnapshot, generation: UInt64) async {
        let signature = signature(of: snapshot)
        if wasTornDown(since: generation) { return }

        if !catchUpLabels.isEmpty, !isCatchUpBackedOff {
            reconcileAlertingFromSystem()
            await flushCatchUp(chainName: snapshot.chainName, generation: generation, signature: signature)
            // A same-second tick is not stale. Only a different snapshot or teardown drops this apply.
            if wasTornDown(since: generation) || isSuperseded(generation, signature: signature) { return }
        }

        guard signature != lastSignature else { return }
        if shouldDeferScheduleRetry(signature) { return }
        if isSuperseded(generation, signature: signature) { return }

        // Reconcile before any cancel so a cold-start alerting alarm is not treated as pending.
        reconcileAlertingFromSystem()
        if wasTornDown(since: generation) || isSuperseded(generation, signature: signature) { return }

        switch snapshot.status {
        case .idle, .completed, .paused:
            cancelAllPending()
            guard !wasTornDown(since: generation), !isSuperseded(generation, signature: signature) else { return }
            lastSignature = signature
            clearScheduleRetry()
        case .running:
            let scheduled = await scheduleUpcoming(snapshot, generation: generation, signature: signature)
            guard !wasTornDown(since: generation), !isSuperseded(generation, signature: signature) else { return }
            if scheduled {
                lastSignature = signature
                clearScheduleRetry()
            } else {
                retrySignature = signature
                retryAfter = Date.now.addingTimeInterval(Self.retryDelay)
            }
        }
    }

    /// Whole-second bucket. Sub-second `endDate` jitter must not reschedule alarms.
    private func signature(of snapshot: EngineSnapshot) -> String {
        let endBucket = Int((snapshot.endDate ?? .distantPast).timeIntervalSince1970)
        return [
            snapshot.status.rawValue,
            snapshot.sessionId?.uuidString ?? "",
            String(snapshot.stepIndex),
            String(endBucket),
        ].joined(separator: "|")
    }

    /// Each remaining step-end gets its own AlarmKit schedule so a suspended
    /// process (or force-quit) can still alert for ends that elapse off-process.
    /// Returns false when a schedule failed or this snapshot went stale. Caller
    /// sets `lastSignature` only on true.
    private func scheduleUpcoming(
        _ snapshot: EngineSnapshot,
        generation: UInt64,
        signature: String
    ) async -> Bool {
        if wasTornDown(since: generation) || isSuperseded(generation, signature: signature) { return false }
        let wanted = snapshot.upcomingEnds
        let wantedIndexes = Set(wanted.map(\.stepIndex))

        let dropped = pendingByStep.keys.filter { !wantedIndexes.contains($0) }
        for index in dropped {
            if let pending = pendingByStep[index] {
                cancelUnprotected(id: pending.id)
                pendingByStep.removeValue(forKey: index)
            }
        }

        adoptMatchingSystemSchedules(wanted)

        for end in wanted {
            if wasTornDown(since: generation) || isSuperseded(generation, signature: signature) { return false }
            if let existing = pendingByStep[end.stepIndex],
               abs(existing.endDate.timeIntervalSince(end.endDate)) < 0.5 {
                remember(step: end.stepIndex, alarmID: existing.id)
                continue
            }
            if let existing = pendingByStep[end.stepIndex] {
                cancelUnprotected(id: existing.id)
                pendingByStep.removeValue(forKey: end.stepIndex)
            }
            let scheduled = await scheduleStepEnd(
                end,
                chainName: snapshot.chainName,
                protectImmediately: false,
                generation: generation,
                signature: signature
            )
            if !scheduled { return false }
        }

        if wasTornDown(since: generation) || isSuperseded(generation, signature: signature) { return false }
        cancelOrphanedSchedules()
        return true
    }

    private func scheduleStepEnd(
        _ end: UpcomingEnd,
        chainName: String,
        protectImmediately: Bool,
        generation: UInt64,
        signature: String
    ) async -> Bool {
        let id = UUID()
        let title = "\(end.label) ended"
        let configuration = makeConfiguration(
            id: id,
            title: title,
            label: end.label,
            chainName: chainName,
            fireDate: end.endDate
        )
        do {
            _ = try await manager.schedule(id: id, configuration: configuration)
            if wasTornDown(since: generation) {
                try? manager.cancel(id: id)
                return false
            }
            // A different snapshot owns ordinary schedules. Same-second ticks are not
            // superseded. Catch-up alarms are for ends that already happened, so keep
            // those unless this run was torn down.
            if isSuperseded(generation, signature: signature), !protectImmediately {
                try? manager.cancel(id: id)
                return false
            }
            if protectImmediately {
                alertingIDs.insert(id)
            } else {
                remember(step: end.stepIndex, alarmID: id)
                pendingByStep[end.stepIndex] = Pending(
                    stepIndex: end.stepIndex,
                    endDate: end.endDate,
                    id: id
                )
            }
            return true
        } catch {
            logger.error("AlarmKit schedule failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func flushCatchUp(chainName: String, generation: UInt64, signature: String) async {
        let labels = catchUpLabels
        catchUpLabels.removeAll()
        var failed = false
        for label in labels {
            if wasTornDown(since: generation) { return }
            let end = UpcomingEnd(stepIndex: -1, endDate: Date.now.addingTimeInterval(0.25), label: label)
            let scheduled = await scheduleStepEnd(
                end,
                chainName: chainName,
                protectImmediately: true,
                generation: generation,
                signature: signature
            )
            if !scheduled, !wasTornDown(since: generation) {
                catchUpLabels.append(label)
                failed = true
            }
        }
        nextCatchUpAttempt = failed ? Date.now.addingTimeInterval(Self.retryDelay) : nil
    }

    /// iOS 26.0 requires `stopButton`. Do not use `Alert(title:)` — that
    /// `init(title:secondaryButton:secondaryButtonBehavior:)` is iOS 26.1+ and
    /// fails against this project's 26.0 deployment target.
    private func makeConfiguration(
        id: UUID,
        title: String,
        label: String,
        chainName: String,
        fireDate: Date
    ) -> AlarmManager.AlarmConfiguration<StepEndMetadata> {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            stopButton: AlarmButton(
                text: "OK",
                textColor: .white,
                systemImageName: "checkmark"
            )
        )
        let attributes = AlarmAttributes<StepEndMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: StepEndMetadata(stepLabel: label, chainName: chainName),
            tintColor: .orange
        )
        // Memberwise init is the iOS 26.0 surface. Sound stays `.default`.
        return AlarmManager.AlarmConfiguration(
            countdownDuration: nil,
            schedule: .fixed(fireDate),
            attributes: attributes,
            stopIntent: AcknowledgeStepIntent(alarmID: id.uuidString),
            secondaryIntent: nil,
            sound: .default
        )
    }

    /// Source of truth after process death: whatever AlarmKit says is alerting
    /// is protected until OK or Stop. Engine restore does not call `onNaturalEnd`.
    private func reconcileAlertingFromSystem() {
        for alarm in (try? manager.alarms) ?? [] {
            if alarm.state == .alerting {
                alertingIDs.insert(alarm.id)
                if let match = pendingByStep.first(where: { $0.value.id == alarm.id }) {
                    remember(step: match.key, alarmID: alarm.id)
                    pendingByStep.removeValue(forKey: match.key)
                }
            }
        }
    }

    /// Reuse still-scheduled system alarms whose fire date matches an upcoming end
    /// (force-quit relaunch) instead of cancelling and creating a new UUID.
    private func adoptMatchingSystemSchedules(_ wanted: [UpcomingEnd]) {
        let owned = alertingIDs.union(Set(pendingByStep.values.map(\.id)))
        for alarm in (try? manager.alarms) ?? [] {
            if owned.contains(alarm.id) { continue }
            if alarm.state == .alerting { continue }
            guard let date = fixedDate(of: alarm) else { continue }
            guard let end = wanted.first(where: { abs($0.endDate.timeIntervalSince(date)) < 0.5 }) else {
                continue
            }
            if pendingByStep[end.stepIndex] != nil { continue }
            remember(step: end.stepIndex, alarmID: alarm.id)
            pendingByStep[end.stepIndex] = Pending(stepIndex: end.stepIndex, endDate: date, id: alarm.id)
        }
    }

    private func cancelOrphanedSchedules() {
        let keep = alertingIDs.union(Set(pendingByStep.values.map(\.id)))
        for alarm in (try? manager.alarms) ?? [] {
            if keep.contains(alarm.id) { continue }
            if alarm.state == .alerting {
                alertingIDs.insert(alarm.id)
                continue
            }
            try? manager.cancel(id: alarm.id)
            stepIndexByAlarmID.removeValue(forKey: alarm.id)
        }
    }

    private func cancelAllPending() {
        for pending in pendingByStep.values {
            cancelUnprotected(id: pending.id)
        }
        pendingByStep.removeAll()
    }

    /// Never cancel/stop an alerting step-end except OK (`noteAcknowledged`) or Stop (`tearDownAll`).
    private func cancelUnprotected(id: UUID) {
        guard !alertingIDs.contains(id) else { return }
        try? manager.cancel(id: id)
        stepIndexByAlarmID.removeValue(forKey: id)
    }

    private func fixedDate(of alarm: Alarm) -> Date? {
        switch alarm.schedule {
        case .fixed(let date):
            return date
        default:
            return nil
        }
    }

    private func remember(step: Int, alarmID: UUID) {
        guard step >= 0 else { return }
        stepIndexByAlarmID[alarmID] = step
    }

    /// True when Stop/Start tore this attempt down, or a newer snapshot has a different signature.
    /// Same-second engine ticks share a signature and must not cancel an in-flight schedule.
    private func isSuperseded(_ generation: UInt64, signature: String) -> Bool {
        if wasTornDown(since: generation) { return true }
        guard let latest = latestSnapshot else { return false }
        return self.signature(of: latest) != signature
    }

    private func wasTornDown(since generation: UInt64) -> Bool {
        tornDownGeneration > generation
    }

    private var isCatchUpBackedOff: Bool {
        guard let nextCatchUpAttempt else { return false }
        return Date.now < nextCatchUpAttempt
    }

    private func shouldDeferScheduleRetry(_ signature: String) -> Bool {
        guard signature == retrySignature, let retryAfter else { return false }
        return Date.now < retryAfter
    }

    private func clearScheduleRetry() {
        retrySignature = nil
        retryAfter = nil
    }

    private func tearDownAll() {
        cancelAllPending()
        for id in alertingIDs {
            try? manager.stop(id: id)
            try? manager.cancel(id: id)
        }
        alertingIDs.removeAll()
        catchUpLabels.removeAll()
        acknowledgedSteps.removeAll()
        stepIndexByAlarmID.removeAll()
        lastSignature = ""
        clearScheduleRetry()
        nextCatchUpAttempt = nil
        // `alarms` is a throwing getter (`get throws`) — must use try.
        for alarm in (try? manager.alarms) ?? [] {
            try? manager.stop(id: alarm.id)
            try? manager.cancel(id: alarm.id)
        }
    }
}
