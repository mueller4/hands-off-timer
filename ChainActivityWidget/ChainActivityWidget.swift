import ActivityKit
import SwiftUI
import WidgetKit

struct ChainActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChainActivityAttributes.self) { context in
            // Compact Lock Screen card (also the unlocked banner on non-Island phones).
            CompactLockScreen(context: context)
        } dynamicIsland: { context in
            // Compact + minimal are the defaults. Expanded regions render only
            // when the user long-presses / expands the Island — never as a
            // full-width banner while unlocked.
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.label)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text("Step \(context.state.stepIndex + 1)/\(context.state.stepCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                countdown(context)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .frame(minWidth: 36, maxWidth: 52)
                    .minimumScaleFactor(0.7)
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    @ViewBuilder
    private func countdown(_ context: ActivityViewContext<ChainActivityAttributes>) -> some View {
        if context.state.isPaused {
            Text("Paused")
        } else {
            Text(timerInterval: Date.now...max(context.state.endDate, Date.now), countsDown: true)
        }
    }
}

private struct CompactLockScreen: View {
    let context: ActivityViewContext<ChainActivityAttributes>

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.body.weight(.semibold))
            Text(context.state.label)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            Group {
                if context.state.isPaused {
                    Text("Paused")
                        .font(.caption.weight(.semibold))
                } else {
                    Text(timerInterval: Date.now...max(context.state.endDate, Date.now), countsDown: true)
                        .font(.body.monospacedDigit().weight(.semibold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 44)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .activityBackgroundTint(Color.black.opacity(0.25))
        .activitySystemActionForegroundColor(.white)
    }
}
