import AlarmKit
import Foundation

/// Shared AlarmKit metadata. Compiled into the app and the widget extension.
public struct StepEndMetadata: AlarmMetadata {
    public var stepLabel: String
    public var chainName: String

    public init(stepLabel: String = "", chainName: String = "") {
        self.stepLabel = stepLabel
        self.chainName = chainName
    }
}

extension Notification.Name {
    /// Posted when the user acknowledges a step-end alarm. Navigation only — never mutate the engine.
    public static let handsOffOpenRun = Notification.Name("handsOff.openRun")
}
