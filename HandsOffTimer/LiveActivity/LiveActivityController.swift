import ActivityKit
import Foundation

/// Best-effort Live Activity. Compact Dynamic Island by default (never expanded-on-start).
/// Survives force-quit only while the system keeps the activity; not reboot survival.
/// Never blocks engine auto-advance. Never passes an alertConfiguration (that would
/// expand the Island / show a full-width unlocked banner).
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<ChainActivityAttributes>?
    private var lastSignature = ""

    private init() {
        activity = Activity<ChainActivityAttributes>.activities.first
    }

    func sync(_ snapshot: EngineSnapshot) {
        // Round the deadline to whole seconds so 20 Hz engine ticks do not
        // spam Activity.update (that throttles the presentation and blanks the timer).
        let deadlineBucket = Int((snapshot.endDate ?? .distantPast).timeIntervalSince1970)
        let signature = [
            snapshot.status.rawValue,
            snapshot.sessionId?.uuidString ?? "",
            String(snapshot.stepIndex),
            String(deadlineBucket),
            snapshot.status == .paused ? "p" : "r",
        ].joined(separator: "|")
        guard signature != lastSignature else { return }
        lastSignature = signature

        Task { await apply(snapshot) }
    }

    private func apply(_ snapshot: EngineSnapshot) async {
        switch snapshot.status {
        case .idle, .completed:
            await endForRun()
        case .running, .paused:
            await upsert(snapshot)
        }
    }

    private func upsert(_ snapshot: EngineSnapshot) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let remaining = max(0, snapshot.remaining)
        let now = Date()
        let rawEnd = snapshot.endDate ?? now.addingTimeInterval(remaining)
        // Timer Text collapses when endDate <= now. Keep a future date while running.
        let endDate: Date
        if snapshot.status == .running {
            endDate = rawEnd.timeIntervalSince(now) >= 1 ? rawEnd : now.addingTimeInterval(max(remaining, 1))
        } else {
            endDate = rawEnd
        }
        let state = ChainActivityAttributes.ContentState(
            stepIndex: snapshot.stepIndex,
            stepCount: snapshot.stepCount,
            label: snapshot.label,
            endDate: endDate,
            remainingText: Formatters.remaining(remaining),
            nextLabel: snapshot.nextLabel ?? "",
            isPaused: snapshot.status == .paused
        )
        // No alertConfiguration — compact Island stays compact; lock card stays compact.
        // staleDate must not equal endDate: a slightly-past deadline would dim/hide the
        // countdown the moment the step is about to end.
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(60))

        if let activity {
            await activity.update(content)
            return
        }

        let attributes = ChainActivityAttributes(chainName: snapshot.chainName)
        activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    /// Stop / new Home Start. Ends Island + Lock card for the prior run, including
    /// any system leftover after force-quit. Does not touch ChainEngine.
    func endForRun() async {
        lastSignature = ""
        if let activity {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.activity = nil
        }
        for leftover in Activity<ChainActivityAttributes>.activities {
            await leftover.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
    }
}
