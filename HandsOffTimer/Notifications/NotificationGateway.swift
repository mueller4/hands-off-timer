import Foundation

/// Dead stub. Local notifications are **not** the step-end path.
/// Natural step-end breakthrough uses AlarmKit (`AlarmKitGateway`) only.
/// Do not schedule, cancel, or present from this type.
///
/// `Notification.Name.handsOffOpenRun` lives next to `StepEndMetadata`.
/// AppDelegate posts that name for leftover local-notification taps (navigation only).
/// AlarmKit OK does **not** post it (`AcknowledgeStepIntent.openAppWhenRun == false`).
@MainActor
final class NotificationGateway {
    static let shared = NotificationGateway()

    private init() {}
}
