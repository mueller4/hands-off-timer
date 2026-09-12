import Foundation
import UserNotifications

extension Notification.Name {
    /// Posted when the user taps a local notification. Navigation only — never mutate the engine.
    static let handsOffOpenRun = Notification.Name("handsOff.openRun")
}

/// Schedules local notifications from engine snapshots.
/// Never pauses, stops, resets, or delays the chain.
@MainActor
final class NotificationGateway {
    static let shared = NotificationGateway()

    static let purpose =
        "Hands-Off Timer notifies you when each step ends so you can keep moving."

    private var lastSignature = ""
    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
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

        Task { await self.apply(snapshot) }
    }

    private func apply(_ snapshot: EngineSnapshot) async {
        await cancelSessionNotifications()
        guard snapshot.status == .running, let sessionId = snapshot.sessionId else { return }

        for (offset, end) in snapshot.upcomingEnds.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = end.label
            if offset + 1 < snapshot.upcomingEnds.count {
                content.body = "Next: \(snapshot.upcomingEnds[offset + 1].label)"
            } else {
                content.body = "Chain complete"
            }
            content.sound = .default
            content.userInfo = [
                "sessionId": sessionId.uuidString,
                "stepIndex": end.stepIndex,
                "kind": "natural-end",
            ]

            let interval = max(0.1, end.endDate.timeIntervalSinceNow)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifier(sessionId: sessionId, stepIndex: end.stepIndex),
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func identifier(sessionId: UUID, stepIndex: Int) -> String {
        "hands-off.\(sessionId.uuidString).\(stepIndex)"
    }

    private func cancelSessionNotifications() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("hands-off.") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}
