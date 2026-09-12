import AlarmKit
import AppIntents
import Foundation

/// System stop / OK on a step-end alarm. Opens Run on the already-advanced engine state.
/// Must never pause, stop, skip, or reschedule ChainEngine.
///
/// `LiveActivityIntent` runs in the **app** process. Keep this type in the app target
/// (widget does not link it — that is a common Command Ld failure).
public struct AcknowledgeStepIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "OK"
    public static var description = IntentDescription(
        "Acknowledges a step-end alarm. The next timer is already running."
    )
    public static var openAppWhenRun: Bool = true

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
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .handsOffOpenRun, object: nil)
        }
        return .result()
    }
}
