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
                        .minimumScaleFactor(0.8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "alarm.fill")
                        .font(.body.weight(.semibold))
                        .imageScale(.medium)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .font(.caption.weight(.semibold))
                    .imageScale(.small)
            } compactTrailing: {
                Text("OK")
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)
                    .frame(maxWidth: 28, alignment: .trailing)
            } minimal: {
                Image(systemName: "alarm.fill")
                    .imageScale(.small)
            }
        }
    }

    @ViewBuilder
    private func compactAlert(_ context: ActivityViewContext<AlarmAttributes<StepEndMetadata>>) -> some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "alarm.fill")
                    .font(.body.weight(.semibold))
                    .imageScale(.medium)
                Text(label(context))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .layoutPriority(0)

            Spacer(minLength: 12)

            Text("OK")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .activityBackgroundTint(Color.orange.opacity(0.35))
        .activitySystemActionForegroundColor(.white)
    }

    private func label(_ context: ActivityViewContext<AlarmAttributes<StepEndMetadata>>) -> String {
        let step = context.attributes.metadata?.stepLabel ?? "Step"
        return "\(step) ended"
    }
}
