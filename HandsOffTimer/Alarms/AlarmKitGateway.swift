import AlarmKit
import Foundation
import SwiftUI

/// Schedules AlarmKit step-end alarms from engine snapshots.
/// Never pauses, stops, resets, or delays the chain — ChainEngine is independent.
@MainActor
final class AlarmKitGateway {
    static let shared = AlarmKitGateway()

    static let purpose =
        "Hands-Off Timer uses alarms so each step can break through Silent and Focus when it ends. The next timer is already running — acknowledge when you’re ready."

    private let manager = AlarmManager.shared
    private var pending: Pending?
    private var alertingIDs: Set<UUID> = []
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
    func noteNaturalEnd(_ event: NaturalEndEvent) {
        if let pending, pending.stepIndex == event.completedIndex {
            alertingIDs.insert(pending.id)
            self.pending = nil
        }
    }

    /// User tapped Stop. Cancel scheduled + alerting alarms for this run.
    /// Does not touch ChainEngine — the caller already stopped it.
    func cancelAllForRun() {
        Task { await tearDownAll() }
    }

    func sync(_ snapshot: EngineSnapshot) {
        let signature = [
            snapshot.status.rawValue,
            snapshot.sessionId?.uuidString ?? "",
            String(snapshot.stepIndex),
            String(snapshot.endDate?.timeIntervalSince1970 ?? 0),
        ].joined(separator: "|")
        guard signature != lastSignature else { return }
        lastSignature = signature
        Task { await apply(snapshot) }
    }

    private func apply(_ snapshot: EngineSnapshot) async {
        switch snapshot.status {
        case .idle, .completed:
            // Drop the not-yet-fired schedule. Alerting alarms stay until the user
            // acknowledges, unless `cancelAllForRun()` already tore them down (Stop).
            cancelPending()
        case .paused:
            cancelPending()
        case .running:
            await scheduleCurrentStep(snapshot)
        }
    }

    private func scheduleCurrentStep(_ snapshot: EngineSnapshot) async {
        guard let end = snapshot.upcomingEnds.first else {
            cancelPending()
            return
        }

        if let pending, pending.stepIndex == end.stepIndex,
           abs(pending.endDate.timeIntervalSince(end.endDate)) < 0.5 {
            return
        }

        cancelPending()

        let id = UUID()
        let title = "\(end.label) ended"

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title)
        )

        let attributes = AlarmAttributes<StepEndMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: StepEndMetadata(stepLabel: end.label, chainName: snapshot.chainName),
            tintColor: .orange
        )

        let configuration = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(end.endDate),
            attributes: attributes,
            stopIntent: AcknowledgeStepIntent(alarmID: id.uuidString),
            sound: .default
        )

        do {
            _ = try await manager.schedule(id: id, configuration: configuration)
            pending = Pending(stepIndex: end.stepIndex, endDate: end.endDate, id: id)
        } catch {
            pending = nil
        }
    }

    private func cancelPending() {
        guard let pending else { return }
        if !alertingIDs.contains(pending.id) {
            try? manager.cancel(id: pending.id)
        }
        self.pending = nil
    }

    private func tearDownAll() {
        cancelPending()
        for id in alertingIDs {
            try? manager.stop(id: id)
            try? manager.cancel(id: id)
        }
        alertingIDs.removeAll()
        for alarm in manager.alarms {
            try? manager.stop(id: alarm.id)
            try? manager.cancel(id: alarm.id)
        }
    }
}
