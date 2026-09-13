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
    /// Posted by Island / deep-link / leftover local-notification taps to open Run.
    /// Not posted by AlarmKit OK (`AcknowledgeStepIntent`) — OK must not foreground the app.
    public static let handsOffOpenRun = Notification.Name("handsOff.openRun")
}
