import ActivityKit
import Foundation

/// Best-effort Live Activity. Survives force-quit only while the system keeps the activity;
/// not reboot survival. Never blocks engine auto-advance.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<ChainActivityAttributes>?
    private var lastSignature = ""

    private init() {
        activity = Activity<ChainActivityAttributes>.activities.first
    }

    func sync(_ snapshot: EngineSnapshot) {
        let signature = [
            snapshot.status.rawValue,
            snapshot.sessionId?.uuidString ?? "",
            String(snapshot.stepIndex),
            String(snapshot.endDate?.timeIntervalSince1970 ?? 0),
            snapshot.status == .paused ? "p" : "r",
        ].joined(separator: "|")
        guard signature != lastSignature else { return }
        lastSignature = signature

        Task { await apply(snapshot) }
    }

    private func apply(_ snapshot: EngineSnapshot) async {
        switch snapshot.status {
        case .idle, .completed:
            await end()
        case .running, .paused:
            await upsert(snapshot)
        }
    }

    private func upsert(_ snapshot: EngineSnapshot) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = ChainActivityAttributes.ContentState(
            stepIndex: snapshot.stepIndex,
            stepCount: snapshot.stepCount,
            label: snapshot.label,
            endDate: snapshot.endDate ?? Date().addingTimeInterval(snapshot.remaining),
            nextLabel: snapshot.nextLabel ?? "",
            isPaused: snapshot.status == .paused
        )
        let content = ActivityContent(state: state, staleDate: state.endDate)

        if let activity {
            await activity.update(content)
            return
        }

        let attributes = ChainActivityAttributes(chainName: snapshot.chainName)
        activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    private func end() async {
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }
}
