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
                        Text(context.attributes.chainName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(context.state.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
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
                // Do not use `.fixedSize()` here — it blows compact sizing
                // and ActivityKit presents expanded / full-width top chrome.
                countdown(context)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(minWidth: 0, maxWidth: 44, alignment: .trailing)
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

/// One compact row: leading glyph + chain name, trailing mm:ss, Spacer gutter.
/// Name uses layoutPriority(1) so the countdown cannot compress it to zero width.
private struct CompactLockScreen: View {
    let context: ActivityViewContext<ChainActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.body.weight(.semibold))
                    .imageScale(.medium)
                Text(displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

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
            .frame(minWidth: 36, maxWidth: 72, alignment: .trailing)
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .activityBackgroundTint(Color.black.opacity(0.25))
        .activitySystemActionForegroundColor(.white)
    }

    /// Chain display name is required. Step label is appended when it differs.
    private var displayName: String {
        let name = context.attributes.chainName.trimmingCharacters(in: .whitespacesAndNewlines)
        let step = context.state.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            return step.isEmpty ? "Hands-Off Timer" : step
        }
        if step.isEmpty || step.compare(name, options: .caseInsensitive) == .orderedSame {
            return name
        }
        return "\(name) · \(step)"
    }
}
