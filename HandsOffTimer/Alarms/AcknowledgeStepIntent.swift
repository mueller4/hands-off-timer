import AlarmKit
import AppIntents
import Foundation

/// System stop / OK on a step-end alarm. Opens Run on the already-advanced engine state.
/// Must never pause, stop, skip, or reschedule ChainEngine.
struct AcknowledgeStepIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "OK"
    static var description = IntentDescription(
        "Acknowledges a step-end alarm. The next timer is already running."
    )
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init() {
        alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .handsOffOpenRun, object: nil)
        }
        return .result()
    }
}
