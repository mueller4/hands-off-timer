import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ChainActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChainActivityAttributes.self) { context in
            LockScreenBanner(context: context)
                .padding(16)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.chainName)
                            .font(.caption.weight(.semibold))
                        Text(context.state.label)
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context)
                        .font(.title2.monospacedDigit().weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("Step \(context.state.stepIndex + 1) of \(context.state.stepCount)")
                        Spacer()
                        Text(context.state.nextLabel.isEmpty ? "Last step" : "Next: \(context.state.nextLabel)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                countdown(context)
                    .monospacedDigit()
                    .frame(minWidth: 40)
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

private struct LockScreenBanner: View {
    let context: ActivityViewContext<ChainActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.chainName)
                    .font(.subheadline.weight(.semibold))
                Text("Step \(context.state.stepIndex + 1) of \(context.state.stepCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(context.state.label)
                    .font(.headline)
                Text(context.state.nextLabel.isEmpty ? "Last step" : "Next: \(context.state.nextLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Group {
                if context.state.isPaused {
                    VStack {
                        Text("Paused")
                            .font(.caption)
                        Text(remainingString(context.state.endDate.timeIntervalSinceNow))
                            .font(.title.monospacedDigit().weight(.semibold))
                    }
                } else {
                    Text(timerInterval: Date.now...max(context.state.endDate, Date.now), countsDown: true)
                        .font(.title.monospacedDigit().weight(.semibold))
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .activityBackgroundTint(Color.black.opacity(0.25))
        .activitySystemActionForegroundColor(.white)
    }

    private func remainingString(_ interval: TimeInterval) -> String {
        let total = max(0, Int(ceil(interval)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
