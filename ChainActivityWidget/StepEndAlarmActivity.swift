import AlarmKit
import SwiftUI
import WidgetKit

/// Compact AlarmKit presentation so the system keeps the alerting alarm until OK.
/// Expanded Island content is only shown when the user expands; default is compact.
/// Type is one step larger so Lock/Home/Watch-mirrored alerts read at a glance.
struct StepEndAlarmActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<StepEndMetadata>.self) { context in
            compactAlert(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.metadata?.stepLabel ?? "Step ended")
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "alarm.fill")
                        .font(.title3.weight(.semibold))
                        .imageScale(.medium)
                }
            } compactLeading: {
                Image(systemName: "alarm.fill")
                    .font(.body.weight(.semibold))
                    .imageScale(.medium)
            } compactTrailing: {
                Text("OK")
                    .font(.caption.weight(.bold))
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
                    .font(.title3.weight(.semibold))
                    .imageScale(.medium)
                Text(label(context))
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .layoutPriority(0)

            Spacer(minLength: 8)

            Text("OK")
                .font(.subheadline.weight(.semibold))
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
