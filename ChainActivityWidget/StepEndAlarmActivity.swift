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
                        .imageScale(.medium)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .imageScale(.medium)
            } compactTrailing: {
                Text("OK")
                    .font(.caption2.weight(.semibold))
                    .fixedSize()
            } minimal: {
                Image(systemName: "alarm.fill")
                    .imageScale(.medium)
            }
        }
    }

    @ViewBuilder
    private func compactAlert(_ context: ActivityViewContext<AlarmAttributes<StepEndMetadata>>) -> some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "alarm.fill")
                    .imageScale(.medium)
                Text(label(context))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .layoutPriority(0)

            Spacer(minLength: 8)

            Text("OK")
                .font(.caption.weight(.semibold))
                .fixedSize()
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
