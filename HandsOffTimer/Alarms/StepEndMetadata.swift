import AlarmKit
import Foundation

/// Shared AlarmKit metadata. Compiled into the app and the widget extension.
struct StepEndMetadata: AlarmMetadata {
    var stepLabel: String
    var chainName: String

    init(stepLabel: String = "", chainName: String = "") {
        self.stepLabel = stepLabel
        self.chainName = chainName
    }
}

extension Notification.Name {
    /// Posted when the user acknowledges a step-end alarm. Navigation only — never mutate the engine.
    static let handsOffOpenRun = Notification.Name("handsOff.openRun")
}
