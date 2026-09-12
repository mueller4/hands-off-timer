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

    /// Not-yet-fired schedules, keyed by engine step index.
    private var pendingByStep: [Int: Pending] = [:]
    /// Step-end alarms that are alerting (or catch-up alarms about to alert). Never cancel/stop these except OK or Stop.
    private var alertingIDs: Set<UUID> = []
    /// Natural ends that had no pending schedule (in-process catch-up). Flushed on the next apply.
    private var catchUpLabels: [String] = []
    private var lastSignature = ""

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
    func noteNaturalEnd(_ event: NaturalEndEvent) {
        if let pending = pendingByStep[event.completedIndex] {
            alertingIDs.insert(pending.id)
            pendingByStep.removeValue(forKey: event.completedIndex)
            return
        }
        catchUpLabels.append(event.completedLabel)
    }

    /// OK / stop intent ran. Bookkeeping only — the intent already stopped the alarm.
    /// Must never pause, stop, skip, or reschedule ChainEngine.
    func noteAcknowledged(id: UUID) {
        alertingIDs.remove(id)
        pendingByStep = pendingByStep.filter { $0.value.id != id }
    }

    /// Stop, or Home Start of a new chain. Cancel scheduled + alerting alarms
    /// for the prior run. Does not touch ChainEngine.
    func cancelAllForRun() {
        tearDownAll()
    }

    func sync(_ snapshot: EngineSnapshot) {
        Task { await apply(snapshot) }
    }

    private func apply(_ snapshot: EngineSnapshot) async {
        // Always reconcile first so a cold-start / force-quit restore cannot
        // treat an already-alerting alarm as cancellable pending.
        reconcileAlertingFromSystem()
        await flushCatchUp(chainName: snapshot.chainName)

        let signature = [
            snapshot.status.rawValue,
            snapshot.sessionId?.uuidString ?? "",
            String(snapshot.stepIndex),
            String(snapshot.endDate?.timeIntervalSince1970 ?? 0),
        ].joined(separator: "|")
        guard signature != lastSignature else { return }
        lastSignature = signature

        switch snapshot.status {
        case .idle, .completed:
            // Drop not-yet-fired schedules. Alerting alarms stay until OK, unless Stop.
            cancelAllPending()
        case .paused:
            cancelAllPending()
        case .running:
            await scheduleUpcoming(snapshot)
        }
    }

    /// Each remaining step-end gets its own AlarmKit schedule so a suspended
    /// process (or force-quit) can still alert for ends that elapse off-process.
    private func scheduleUpcoming(_ snapshot: EngineSnapshot) async {
        let wanted = snapshot.upcomingEnds
        let wantedIndexes = Set(wanted.map(\.stepIndex))

        for (index, pending) in pendingByStep {
            if !wantedIndexes.contains(index) {
                cancelUnprotected(id: pending.id)
                pendingByStep.removeValue(forKey: index)
            }
        }

        adoptMatchingSystemSchedules(wanted)

        for end in wanted {
            if let existing = pendingByStep[end.stepIndex],
               abs(existing.endDate.timeIntervalSince(end.endDate)) < 0.5 {
                continue
            }
            if let existing = pendingByStep[end.stepIndex] {
                cancelUnprotected(id: existing.id)
                pendingByStep.removeValue(forKey: end.stepIndex)
            }
            await scheduleStepEnd(end, chainName: snapshot.chainName, protectImmediately: false)
        }

        cancelOrphanedSchedules()
    }

    private func scheduleStepEnd(
        _ end: UpcomingEnd,
        chainName: String,
        protectImmediately: Bool
    ) async {
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
            if protectImmediately {
                alertingIDs.insert(id)
            } else {
                pendingByStep[end.stepIndex] = Pending(
                    stepIndex: end.stepIndex,
                    endDate: end.endDate,
                    id: id
                )
            }
        } catch {
            logger.error("AlarmKit schedule failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func flushCatchUp(chainName: String) async {
        let labels = catchUpLabels
        catchUpLabels.removeAll()
        for label in labels {
            let end = UpcomingEnd(stepIndex: -1, endDate: Date.now.addingTimeInterval(0.25), label: label)
            await scheduleStepEnd(end, chainName: chainName, protectImmediately: true)
        }
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
                pendingByStep = pendingByStep.filter { $0.value.id != alarm.id }
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
    }

    private func fixedDate(of alarm: Alarm) -> Date? {
        switch alarm.schedule {
        case .fixed(let date):
            return date
        default:
            return nil
        }
    }

    private func tearDownAll() {
        cancelAllPending()
        for id in alertingIDs {
            try? manager.stop(id: id)
            try? manager.cancel(id: id)
        }
        alertingIDs.removeAll()
        catchUpLabels.removeAll()
        lastSignature = ""
        // `alarms` is a throwing getter (`get throws`) — must use try.
        for alarm in (try? manager.alarms) ?? [] {
            try? manager.stop(id: alarm.id)
            try? manager.cancel(id: alarm.id)
        }
    }
}
