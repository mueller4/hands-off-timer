import ActivityKit
import SwiftUI
import WidgetKit

struct ChainActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChainActivityAttributes.self) { context in
            // Compact Lock Screen / Home Screen banner / StandBy / Watch-mirrored card.
            CompactLockScreen(context: context)
        } dynamicIsland: { context in
            // Compact + minimal are the defaults. Expanded regions render only
            // when the user long-presses / expands the Island — never as a
            // full-width banner while unlocked.
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.label)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("Step \(context.state.stepIndex + 1)/\(context.state.stepCount)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .fixedSize(horizontal: true, vertical: false)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .imageScale(.medium)
                    .font(.body.weight(.semibold))
            } compactTrailing: {
                countdown(context)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: true, vertical: false)
            } minimal: {
                Image(systemName: "timer")
                    .imageScale(.medium)
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

/// Leading cluster (glyph + label) / trailing time. `frame(maxWidth: .infinity)` is
/// required so Spacer actually pushes the countdown to the trailing edge of the banner.
/// Type is one step larger than the compact polish pass so Lock/Home/Watch-mirrored
/// presentations read at a glance. No minWidth frames (those pad Island trailing).
private struct CompactLockScreen: View {
    let context: ActivityViewContext<ChainActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.title3.weight(.semibold))
                    .imageScale(.medium)
                Text(context.state.label)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .layoutPriority(0)

            Spacer(minLength: 8)

            Group {
                if context.state.isPaused {
                    Text("Paused")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Text(timerInterval: Date.now...max(context.state.endDate, Date.now), countsDown: true)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .multilineTextAlignment(.trailing)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .activityBackgroundTint(Color.black.opacity(0.25))
        .activitySystemActionForegroundColor(.white)
    }
}
