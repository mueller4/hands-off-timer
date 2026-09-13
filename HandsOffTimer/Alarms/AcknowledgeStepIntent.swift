import AlarmKit
import AppIntents
import Foundation

/// System stop / OK on a step-end alarm.
/// Stops that alarm only. Does **not** open the app or present Run.
/// Must never pause, stop, skip, or reschedule ChainEngine.
///
/// `LiveActivityIntent` runs in the **app** process. Keep this type in the app target
/// (widget does not link it — that is a common Command Ld failure).
public struct AcknowledgeStepIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "OK"
    public static var description = IntentDescription(
        "Acknowledges a step-end alarm. The next timer is already running."
    )
    /// Hands-off: OK must not force-open the app. Island / deep-link / leftover
    /// notification taps still post `.handsOffOpenRun` from their own paths.
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Alarm ID")
    public var alarmID: String

    public init() {
        alarmID = ""
    }

    public init(alarmID: String) {
        self.alarmID = alarmID
    }

    public func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
            await AlarmKitGateway.shared.noteAcknowledged(id: id)
        }
        return .result()
    }
}
