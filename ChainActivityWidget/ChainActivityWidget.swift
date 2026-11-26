import ActivityKit
import SwiftUI
import WidgetKit

struct ChainActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChainActivityAttributes.self) { context in
            // Medium stays the Lock Screen / banner / StandBy card.
            // `.small` is CarPlay Dashboard and the Watch Smart Stack.
            ActivityFamilyContent(context: context)
        } dynamicIsland: { context in
            // Compact + minimal are the defaults. Expanded regions render only
            // when the user long-presses the Island. Do not pass alertConfiguration
            // from LiveActivityController — that expands / full-width unlocked banner.
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    // Finite width + tail truncate (PR #10) only stops trailing
                    // overflow. The leading ear’s capsule curve still shears the
                    // first glyph if text paints flush to the left/top mask
                    // (LA-2). Inset from that clip path; keep minWidth 0,
                    // modest maxWidth, and tail ellipsis for long names.
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.chainName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.75)
                        Text(context.state.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.leading, 10)
                    .padding(.top, 4)
                    .frame(minWidth: 0, maxWidth: 104, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing, priority: 1) {
                    countdown(context)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.trailing)
                        .layoutPriority(1)
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
        // iOS 18 API; deployment is already 26.0, so this is not availability-gated.
        .supplementalActivityFamilies([.small])
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

/// Routes `.small` (CarPlay Dashboard, Watch Smart Stack) to its own layout.
/// Every other family keeps `CompactLockScreen` and the Island is untouched.
private struct ActivityFamilyContent: View {
    @Environment(\.activityFamily) private var activityFamily
    let context: ActivityViewContext<ChainActivityAttributes>

    var body: some View {
        if activityFamily == .small {
            SmallActivityLayout(
                stepName: stepName,
                endDate: context.state.endDate,
                remainingText: context.state.remainingText,
                isPaused: context.state.isPaused
            )
        } else {
            CompactLockScreen(context: context)
        }
    }

    /// Current step label, one line in the small card. A blank label falls
    /// back to the chain name so the row is never empty.
    private var stepName: String {
        let step = context.state.label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !step.isEmpty { return step }
        let chain = context.attributes.chainName.trimmingCharacters(in: .whitespacesAndNewlines)
        return chain.isEmpty ? "Hands-Off Timer" : chain
    }
}

/// Compact small-family card. No controls.
///
/// Digits use the primary label color — black on a light system background,
/// white in dark — matching Run. `#0A84FF` is only the glyph and the Paused label.
///
/// If this card does not read well on the CarPlay Dashboard, the follow-up is
/// the commented `.disfavoredLocations([.carPlay], for: [.systemSmall])` on
/// `HandsOffTimerHomeWidget`. Do not add that until QA says so.
private struct SmallActivityLayout: View {
    var stepName: String
    var endDate: Date
    var remainingText: String
    var isPaused: Bool

    var body: some View {
        // Prefer the "Paused" caption. A short CarPlay / Watch card keeps the
        // pause glyph and frozen digits when the caption does not fit.
        Group {
            if isPaused {
                ViewThatFits(in: .vertical) {
                    card(showsPausedCaption: true)
                    card(showsPausedCaption: false)
                }
            } else {
                card(showsPausedCaption: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // The small family cannot grow. Scale through xxxLarge, then stop
        // before accessibility sizes so the name stays one line and the
        // countdown is not clipped.
        .dynamicTypeSize(.xSmall ... .xxxLarge)
        .activityBackgroundTint(Color(.systemBackground))
    }

    private func card(showsPausedCaption: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: isPaused ? "pause.fill" : "timer")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(WidgetPalette.accent)
                    .accessibilityHidden(true)
                    .layoutPriority(1)

                Text(stepName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .allowsTightening(true)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }

            digits

            if isPaused && showsPausedCaption {
                Text("Paused")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetPalette.accent)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    /// Live countdown on its own line so `Text(timerInterval:)` can take the
    /// width it needs. Do not use `.fixedSize()` — that blows the activity width.
    /// The range is a week ending at `endDate`; an empty range renders blank,
    /// and steps are at most 99 minutes so "now" stays inside it while running.
    private var digits: some View {
        Group {
            if isPaused {
                Text(pausedDigits)
                    .accessibilityLabel("Paused, \(pausedDigits) remaining")
            } else {
                Text(timerInterval: runningInterval, countsDown: true, showsHours: true)
            }
        }
        .font(.system(.title2, design: .monospaced).weight(.semibold))
        .monospacedDigit()
        .foregroundStyle(.primary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pausedDigits: String {
        let text = remainingText.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "0:00" : text
    }

    private var runningInterval: ClosedRange<Date> {
        let end = endDate
        let start = end.addingTimeInterval(TimeInterval(-604_800))
        return start...end
    }
}

private func smallActivityPreview(
    stepName: String,
    remainingSeconds: Int,
    remainingText: String,
    isPaused: Bool,
    colorScheme: ColorScheme = .light
) -> some View {
    SmallActivityLayout(
        stepName: stepName,
        endDate: .now.addingTimeInterval(TimeInterval(remainingSeconds)),
        remainingText: remainingText,
        isPaused: isPaused
    )
    .frame(width: 188)
    .background(Color(.systemBackground))
    .preferredColorScheme(colorScheme)
}

#Preview("Small — Running") {
    smallActivityPreview(
        stepName: "Stretch and fold the dough",
        remainingSeconds: 12 * 60 + 34,
        remainingText: "12:34",
        isPaused: false
    )
}

#Preview("Small — Paused") {
    smallActivityPreview(
        stepName: "Rest",
        remainingSeconds: 4 * 60 + 30,
        remainingText: "4:30",
        isPaused: true
    )
}

#Preview("Small — Running, Dark") {
    smallActivityPreview(
        stepName: "Stretch and fold the dough",
        remainingSeconds: 12 * 60 + 34,
        remainingText: "12:34",
        isPaused: false,
        colorScheme: .dark
    )
}

#Preview("Small — Paused, Dark") {
    smallActivityPreview(
        stepName: "Rest",
        remainingSeconds: 4 * 60 + 30,
        remainingText: "4:30",
        isPaused: true,
        colorScheme: .dark
    )
}
