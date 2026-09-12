import AlarmKit
import SwiftUI
import WidgetKit

/// Compact AlarmKit presentation so the system keeps the alerting alarm until OK.
/// Expanded Island content is only shown when the user expands; default is compact.
struct StepEndAlarmActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<StepEndMetadata>.self) { context in
            compactAlert(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.metadata?.stepLabel ?? "Step ended")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "alarm.fill")
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
            } compactTrailing: {
                Text("OK")
                    .font(.caption.weight(.semibold))
            } minimal: {
                Image(systemName: "alarm.fill")
            }
        }
    }

    @ViewBuilder
    private func compactAlert(_ context: ActivityViewContext<AlarmAttributes<StepEndMetadata>>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "alarm.fill")
            Text(label(context))
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("OK")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .activityBackgroundTint(Color.orange.opacity(0.35))
        .activitySystemActionForegroundColor(.white)
    }

    private func label(_ context: ActivityViewContext<AlarmAttributes<StepEndMetadata>>) -> String {
        let step = context.attributes.metadata?.stepLabel ?? "Step"
        return "\(step) ended"
    }
}
