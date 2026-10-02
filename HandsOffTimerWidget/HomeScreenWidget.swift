import SwiftUI
import WidgetKit

/// Home Screen widget for Hands-Off Timer. systemSmall + systemMedium only.
/// Layout matches the first frame sheet (Empty / Idle / Running). Color is a
/// recolor of that sheet: navy titles, `#0A84FF` timer glyph and countdown.
/// Glance + open only — no Start, Pause, Skip, or Stop.
@main
struct HandsOffTimerHomeWidgets: WidgetBundle {
    var body: some Widget {
        HandsOffTimerHomeWidget()
    }
}

struct HandsOffTimerHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: HomeWidgetKind.id, provider: HomeWidgetProvider()) { entry in
            HomeWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hands-Off Timer")
        .description("See your next chain or live countdown on the Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct HomeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HomeWidgetEntry {
        HomeWidgetEntry(date: .now, phase: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (HomeWidgetEntry) -> Void) {
        let disk = HomeWidgetDisk.load() ?? .empty
        let plan = HomeWidgetTimeline.plan(disk: disk, now: .now)
        let item = plan.items[0]
        completion(HomeWidgetEntry(date: item.date, phase: item.phase))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeWidgetEntry>) -> Void) {
        let disk = HomeWidgetDisk.load() ?? .empty
        let plan = HomeWidgetTimeline.plan(disk: disk, now: .now)
        let entries = plan.items.map { HomeWidgetEntry(date: $0.date, phase: $0.phase) }
        let policy: TimelineReloadPolicy = plan.reloadAtEnd ? .atEnd : .never
        completion(Timeline(entries: entries, policy: policy))
    }
}

struct HomeWidgetEntry: TimelineEntry {
    var date: Date
    var phase: HomeWidgetPhase
}

struct HomeWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    var entry: HomeWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                medium(entry.phase)
            default:
                small(entry.phase)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
        .containerBackground(Color(.systemBackground), for: .widget)
        .widgetURL(HomeWidgetLink.url(for: entry.phase.destination))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.phase.accessibilityLabel)
    }

    private var titleColor: Color { WidgetPalette.title(colorScheme) }

    // MARK: Small — first sheet

    @ViewBuilder
    private func small(_ phase: HomeWidgetPhase) -> some View {
        switch phase {
        case .empty:
            VStack(alignment: .leading, spacing: 4) {
                timerGlyph(size: 22)
                Spacer(minLength: 8)
                Text("No chains yet")
                    .font(.headline)
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("Open app")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        case .idle(let chain):
            VStack(alignment: .leading, spacing: 2) {
                Text(chain.displayName)
                    .font(.headline)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(chain.stepCountText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("Open to start")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        case .running(let run):
            VStack(alignment: .leading, spacing: 0) {
                Text(run.label)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                countdown(run, size: 40)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 4)
                if !run.stepMeta.isEmpty {
                    Text(run.stepMeta)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }

    // MARK: Medium — first sheet

    @ViewBuilder
    private func medium(_ phase: HomeWidgetPhase) -> some View {
        switch phase {
        case .empty:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    timerGlyph(size: 18)
                    Text("Hands-Off Timer")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text("No chains yet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text("Build a sequence in the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        case .idle(let chain):
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(chain.displayName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 8)
                    Text(chain.stepCountText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(chain.mediumSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 8)
                Text("Open to start")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        case .running(let run):
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(run.chainName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    if !run.stepMeta.isEmpty {
                        Text(run.stepMeta)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                Text(run.label)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                countdown(run, size: 44)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 2)
                Text(run.nextLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func timerGlyph(size: CGFloat) -> some View {
        Image(systemName: "timer")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(WidgetPalette.accent)
            .accessibilityHidden(true)
            .widgetAccentable()
    }

    /// Live countdown from the shared wall-clock end. Paused freezes `remainingText`.
    /// `timerInterval` stays at zero instead of counting up after the step ends.
    @ViewBuilder
    private func countdown(_ run: HomeWidgetRunDisplay, size: CGFloat) -> some View {
        Group {
            if run.isPaused || run.endDate == nil {
                Text(run.remainingText)
            } else if let end = run.endDate, entry.date < end {
                // Stable lower bound (the timeline entry), not Date.now.
                // A zero-length range renders blank — same lesson as Live Activity.
                Text(timerInterval: entry.date...end, countsDown: true)
            } else {
                Text(run.remainingText.isEmpty ? "0:00" : run.remainingText)
            }
        }
        .font(.system(size: size, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(WidgetPalette.accent)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .widgetAccentable()
    }
}
