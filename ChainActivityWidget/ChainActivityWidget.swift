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
            // when the user long-presses the Island. Do not pass alertConfiguration
            // from LiveActivityController — that expands / full-width unlocked banner.
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.label)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("Step \(context.state.stepIndex + 1)/\(context.state.stepCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isPaused {
                        Text("Paused")
                            .font(.caption.weight(.semibold))
                    } else if !context.state.nextLabel.isEmpty {
                        Text("Next \(context.state.nextLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .imageScale(.small)
                    .font(.caption.weight(.semibold))
            } compactTrailing: {
                countdown(context)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 54, alignment: .trailing)
            } minimal: {
                Image(systemName: "timer")
                    .imageScale(.small)
            }
        }
    }

    /// `Text(date, style: .timer)` stays visible even if endDate is slightly past.
    /// Do not use `Date.now...endDate` — a zero-length range renders blank.
    @ViewBuilder
    private func countdown(_ context: ActivityViewContext<ChainActivityAttributes>) -> some View {
        if context.state.isPaused {
            Text(context.state.remainingText)
                .monospacedDigit()
        } else {
            Text(context.state.endDate, style: .timer)
                .monospacedDigit()
        }
    }
}

/// One compact row: leading glyph+label, trailing mm:ss, Spacer gutter.
/// No `fixedSize` (zero-width timer then packs everything leading).
private struct CompactLockScreen: View {
    let context: ActivityViewContext<ChainActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.body.weight(.semibold))
                    .imageScale(.medium)
                Text(context.state.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .layoutPriority(0)

            Spacer(minLength: 12)

            Group {
                if context.state.isPaused {
                    Text(context.state.remainingText)
                        .font(.body.monospacedDigit().weight(.semibold))
                } else {
                    Text(context.state.endDate, style: .timer)
                        .font(.body.monospacedDigit().weight(.semibold))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .multilineTextAlignment(.trailing)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .activityBackgroundTint(Color.black.opacity(0.25))
        .activitySystemActionForegroundColor(.white)
    }
}
