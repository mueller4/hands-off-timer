import SwiftUI

/// Static How It Works guide. Copy is the 1.1 (3) product spec, verbatim.
/// Local text only: no network, no templates, no timer controls.
struct HowItWorksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(HowItWorksContent.sections) { section in
                    HowToSectionRow(section: section)
                }

                Divider()
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Ideas")
                        .font(Font.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(HowItWorksContent.ideas) { idea in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(idea.name)
                                .font(Font.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(idea.steps)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
        .navigationTitle("How It Works")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct HowToSectionRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let section: HowToSection

    /// Accessibility sizes need the full width for the title and body.
    private var showsSymbol: Bool {
        !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showsSymbol {
                Image(systemName: section.symbol)
                    .font(.title3)
                    .foregroundStyle(WidgetPalette.accent)
                    .frame(width: 28, alignment: .center)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(.isHeader)

                Text(section.text)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(nil, value: showsSymbol)
    }
}

private struct HowToSection: Identifiable {
    var id: String { title }
    let symbol: String
    let title: String
    let text: String
}

private struct ChainIdea: Identifiable {
    var id: String { name }
    let name: String
    let steps: String
}

private enum HowItWorksContent {
    static let sections: [HowToSection] = [
        HowToSection(
            symbol: "list.bullet",
            title: "Build a chain",
            text: "A chain is a list of timers that run one after another. Tap + to make one, add steps with a length and an optional label, and drag to reorder."
        ),
        HowToSection(
            symbol: "play.circle",
            title: "Start it",
            text: "Tap a chain on Home to start it. Follow the countdown in the app, the Dynamic Island, or the Lock Screen."
        ),
        HowToSection(
            symbol: "bell",
            title: "When a step ends",
            text: "An alarm sounds and the next step starts on its own. Tap OK to silence the alarm. The next timer keeps running either way."
        ),
        HowToSection(
            symbol: "pause.circle",
            title: "While it runs",
            text: "Pause stops only the current step. Skip jumps to the next step without an alarm. Stop ends the whole chain and cancels its alarms."
        ),
        HowToSection(
            symbol: "square.grid.2x2",
            title: "Widget",
            text: "Add the Hands-Off Timer widget to your Home Screen to see recent chains or the live countdown. Tap it to open the app."
        ),
    ]

    static let ideas: [ChainIdea] = [
        ChainIdea(name: "HIIT", steps: "Work 40s, Rest 20s, Work 40s, Rest 20s, Cooldown 2m."),
        ChainIdea(name: "Cooking", steps: "Sear 3m, Flip 3m, Rest 5m."),
        ChainIdea(name: "Stretching", steps: "Hamstrings 45s, Quads 45s, Shoulders 45s, Calves 45s."),
        ChainIdea(name: "Focus", steps: "Focus 25m, Break 5m, Focus 25m, Long break 15m."),
        ChainIdea(name: "Bedtime", steps: "Bath 15m, Pajamas 5m, Teeth 3m, Story 10m."),
        ChainIdea(name: "Chores", steps: "Wash 45m, Dry 50m, Fold 10m."),
    ]
}

#Preview("How It Works") {
    NavigationStack {
        HowItWorksView()
    }
}

#Preview("How It Works — Dark") {
    NavigationStack {
        HowItWorksView()
    }
    .preferredColorScheme(.dark)
}
