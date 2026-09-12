import Foundation

/// Dead stub. Local notifications are **not** the step-end path.
/// Natural step-end breakthrough uses AlarmKit (`AlarmKitGateway`) only.
/// Do not schedule, cancel, or present from this type.
///
/// `Notification.Name.handsOffOpenRun` lives next to `StepEndMetadata` so the
/// widget extension can share it with `AcknowledgeStepIntent`. AppDelegate still
/// posts that name for leftover local-notification taps (navigation only).
@MainActor
final class NotificationGateway {
    static let shared = NotificationGateway()

    private init() {}
}
