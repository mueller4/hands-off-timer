import Foundation

/// Local notifications are no longer the step-end path.
/// Natural step-end breakthrough uses AlarmKit (`AlarmKitGateway`).
/// `Notification.Name.handsOffOpenRun` lives next to `StepEndMetadata` so the
/// widget extension can share it with `AcknowledgeStepIntent`.
@MainActor
final class NotificationGateway {
    static let shared = NotificationGateway()

    private init() {}
}
