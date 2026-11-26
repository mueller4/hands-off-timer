import SwiftUI

struct RunView: View {
    @Environment(ChainStore.self) private var store
    @Environment(ChainEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var confirmStop = false
    @State private var completeTask: Task<Void, Never>?
    /// Spoken once when the step or pause state changes, not on every tick.
    @State private var spokenToken = Int.min
    @State private var spokenSummary = ""

    var body: some View {
        Group {
            if engine.snapshot.status == .completed {
                done
            } else {
                running
            }
        }
        .background(Color(.systemBackground))
        .confirmationDialog("End this chain?", isPresented: $confirmStop, titleVisibility: .visible) {
            Button("End chain", role: .destructive) {
                completeTask?.cancel()
                AlarmKitGateway.shared.cancelAllForRun()
                engine.stop()
                router.showRun = false
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The remaining steps will not run.")
        }
        .onChange(of: engine.snapshot.status) { _, status in
            refreshSpokenSummary()
            if status == .completed {
                completeTask?.cancel()
                completeTask = Task {
                    try? await Task.sleep(for: .milliseconds(1600))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        engine.acknowledgeComplete()
                        router.showRun = false
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: engine.snapshot.stepIndex) { _, _ in
            refreshSpokenSummary()
        }
        .onAppear {
            refreshSpokenSummary()
            if engine.snapshot.status == .idle {
                router.showRun = false
                dismiss()
            }
        }
        .onDisappear {
            completeTask?.cancel()
        }
    }

    private var running: some View {
        // Compact width keeps the shipping column, including its primary-colored digits.
        // Regular width (open Duo, either window aspect) uses the side-by-side layout.
        if horizontalSizeClass == .regular {
            openOrTabletop
        } else {
            // The 84pt readout plus the 92pt controls overflow a short height
            // (the open Duo screen). Keep this column when it fits; scroll when it does not.
            fittingHeight { runningColumn }
        }
    }

    /// One geometry pass decides tabletop vs side-by-side so the fold rect and the
    /// panes share a coordinate space. Compact width never reaches this view.
    private var openOrTabletop: some View {
        GeometryReader { proxy in
            Group {
                if let division = DuoFold.tabletopFrame(in: proxy) {
                    tabletopRun(in: proxy, division: division)
                } else {
                    sideBySideRun(in: proxy, book: DuoFold.bookFrame(in: proxy))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .transaction { transaction in
            transaction.disablesAnimations = true
        }
    }

    private var runningColumn: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            Text("Step \(engine.snapshot.stepIndex + 1) of \(engine.snapshot.stepCount)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
            Text(engine.snapshot.label)
                .font(.title2.weight(.semibold))
                .padding(.top, 8)
            Spacer()
            CountdownReadout(
                text: Formatters.remaining(engine.snapshot.remaining),
                paused: engine.snapshot.status == .paused
            )
            .equatable()
            Text(engine.snapshot.nextLabel.map { "Next: \($0)" } ?? "Last step")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 20)
            Spacer()
            HStack(spacing: 12) {
                runButton("Skip", systemImage: "forward.end.fill", role: .skip) {
                    engine.skip()
                }
                runButton(
                    engine.snapshot.status == .paused ? "Resume" : "Pause",
                    systemImage: engine.snapshot.status == .paused ? "play.fill" : "pause.fill",
                    role: .primary
                ) {
                    if engine.snapshot.status == .paused {
                        engine.resume()
                    } else {
                        engine.pause()
                    }
                }
                runButton("Stop", systemImage: "stop.fill", role: .stop) {
                    confirmStop = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    private var done: some View {
        fittingHeight { doneColumn }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var doneColumn: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("Done")
                .font(.largeTitle.weight(.semibold))
            Text("\(engine.snapshot.chainName) finished.")
                .foregroundStyle(.secondary)
        }
    }

    /// Portrait (and any height that fits) uses the original stack.
    /// The scroll fallback only appears when that stack's height exceeds the offer,
    /// so spacers still distribute space whenever the screen is tall enough.
    @ViewBuilder
    private func fittingHeight<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ViewThatFits(in: .vertical) {
            content()
            ScrollView {
                content()
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private enum Role { case skip, primary, stop }

    private func runButton(_ title: String, systemImage: String, role: Role, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title2)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if role == .skip {
                    Text("Silent")
                        .font(.caption2)
                        .opacity(0.7)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 92)
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .stop ? Color.red : role == .primary ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(role == .stop ? Color.red.opacity(0.12) : role == .primary ? Color.accentColor : Color(.tertiarySystemFill))
        )
    }

    private func sideBySideRun(in proxy: GeometryProxy, book: CGRect?) -> some View {
        let full = proxy.size
        let gap = book.map { max(0, $0.width) } ?? 0
        let leading = book.map { max(0, $0.minX) } ?? (max(0, full.width - gap) * 0.58)
        let trailing = book.map { max(0, full.width - $0.maxX) } ?? max(0, full.width - leading)
        let separator: CGFloat = book == nil ? 1 : 0
        return HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                openInfo(timeSize: 80)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilitySortPriority(3)
                openControls(minHeight: 44)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .layoutPriority(1)
                    .accessibilitySortPriority(1)
            }
            .frame(width: leading, height: full.height)
            if let book {
                Color.clear
                    .frame(width: max(0, book.width), height: full.height)
                    .accessibilityHidden(true)
            } else {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: separator, height: full.height)
                    .accessibilityHidden(true)
            }
            upcomingList
                .frame(width: max(0, trailing - separator), height: full.height)
                .accessibilitySortPriority(2)
        }
        .frame(width: full.width, height: full.height, alignment: .topLeading)
        .accessibilityElement(children: .contain)
    }

    private func tabletopRun(in proxy: GeometryProxy, division: CGRect) -> some View {
        let top = max(0, division.minY)
        let gap = max(0, division.height)
        return VStack(spacing: 0) {
            openInfo(timeSize: 108)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .frame(height: top)
                .clipped()
            Color.clear
                .frame(height: gap)
                .accessibilityHidden(true)
            ViewThatFits(in: .vertical) {
                openControls(minHeight: 60)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                ScrollView {
                    openControls(minHeight: 60)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
    }

    /// Countdown digits stay the primary label color — the same black (or dark-mode
    /// primary) as the compact run. Only the new chrome uses the accent.
    private func openInfo(timeSize: CGFloat) -> some View {
        VStack(spacing: 8) {
            Text("Step \(engine.snapshot.stepIndex + 1) of \(engine.snapshot.stepCount)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(engine.snapshot.label)
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)
            Text(Formatters.remaining(engine.snapshot.remaining))
                .font(.system(size: timeSize, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.25)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .accessibilityHidden(true)
            stepProgress
                .padding(.top, 4)
            Text(nextLine)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenSummary.isEmpty ? liveSummary : spokenSummary)
    }

    private var stepProgress: some View {
        Capsule()
            .fill(Color(.tertiarySystemFill))
            .frame(height: 4)
            .frame(maxWidth: 280)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(WidgetPalette.accent)
                        .frame(width: max(0, geo.size.width * progressFraction), height: 4)
                }
            }
            .accessibilityHidden(true)
    }

    private var upcomingList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Up next")
                    .font(.title3.weight(.semibold))
                    .padding(.bottom, 8)
                    .accessibilityAddTraits(.isHeader)
                ForEach(upcomingRows) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: row.isCurrent ? "largecircle.fill.circle" : "circle")
                            .font(.body)
                            .foregroundStyle(row.isCurrent ? WidgetPalette.accent : .secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.label)
                                .font(row.isCurrent ? .body.weight(.semibold) : .body)
                                .foregroundStyle(row.isCurrent ? .primary : .secondary)
                            if row.isCurrent && row.isLast {
                                Text("Last step")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        if let duration = row.durationSeconds {
                            Text(Formatters.duration(duration))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(row.isCurrent ? .primary : .secondary)
                        }
                    }
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(upcomingAccessibility(row))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func openControls(minHeight: CGFloat) -> some View {
        let paused = engine.snapshot.status == .paused
        return HStack(spacing: 12) {
            openControl(
                title: "Skip",
                systemImage: "forward.end.fill",
                accessibilityLabel: "Skip to next step",
                minHeight: minHeight,
                kind: .skip
            ) {
                engine.skip()
            }
            openControl(
                title: paused ? "Resume" : "Pause",
                systemImage: paused ? "play.fill" : "pause.fill",
                accessibilityLabel: paused ? "Resume timer" : "Pause timer",
                minHeight: minHeight,
                kind: .pause
            ) {
                if paused {
                    engine.resume()
                } else {
                    engine.pause()
                }
            }
            openControl(
                title: "Stop",
                systemImage: "stop.fill",
                accessibilityLabel: "Stop chain",
                minHeight: minHeight,
                kind: .stop
            ) {
                confirmStop = true
            }
        }
    }

    private enum OpenControlKind { case skip, pause, stop }

    private func openControl(
        title: String,
        systemImage: String,
        accessibilityLabel: String,
        minHeight: CGFloat,
        kind: OpenControlKind,
        action: @escaping () -> Void
    ) -> some View {
        let label = Label(title, systemImage: systemImage)
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .contentShape(Rectangle())
        return Group {
            switch kind {
            case .skip:
                Button(action: action) { label }
                    .buttonStyle(.bordered)
            case .pause:
                Button(action: action) { label }
                    .buttonStyle(.borderedProminent)
                    .tint(WidgetPalette.accent)
            case .stop:
                Button(role: .destructive, action: action) { label }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var activeChain: TimerChain? {
        guard let id = engine.snapshot.chainId else { return nil }
        return store.chain(id: id)
    }

    private var progressFraction: Double {
        let snap = engine.snapshot
        guard let chain = activeChain, chain.steps.indices.contains(snap.stepIndex) else { return 0 }
        let total = Double(chain.steps[snap.stepIndex].durationSeconds)
        guard total > 0 else { return 0 }
        let remaining = min(total, max(0, snap.remaining))
        return 1 - (remaining / total)
    }

    private var nextLine: String {
        let snap = engine.snapshot
        guard let next = snap.nextLabel, !next.isEmpty else { return "Last step" }
        if let chain = activeChain,
           chain.steps.count == snap.stepCount,
           chain.steps.indices.contains(snap.stepIndex + 1) {
            let duration = Formatters.duration(chain.steps[snap.stepIndex + 1].durationSeconds)
            return "Next · \(next)  \(duration)"
        }
        return "Next · \(next)"
    }

    private var upcomingRows: [RunUpcomingRow] {
        let snap = engine.snapshot
        let last = max(0, snap.stepCount - 1)
        if let chain = activeChain, chain.steps.count == snap.stepCount {
            return chain.steps.enumerated().compactMap { index, step in
                guard index >= snap.stepIndex else { return nil }
                return RunUpcomingRow(
                    index: index,
                    label: step.displayLabel(index: index),
                    durationSeconds: step.durationSeconds,
                    isCurrent: index == snap.stepIndex,
                    isLast: index == last
                )
            }
        }
        var rows = [
            RunUpcomingRow(
                index: snap.stepIndex,
                label: snap.label,
                durationSeconds: nil,
                isCurrent: true,
                isLast: snap.nextLabel == nil
            )
        ]
        if let next = snap.nextLabel {
            rows.append(
                RunUpcomingRow(
                    index: snap.stepIndex + 1,
                    label: next,
                    durationSeconds: nil,
                    isCurrent: false,
                    isLast: snap.stepIndex + 1 >= last
                )
            )
        }
        return rows
    }

    private func upcomingAccessibility(_ row: RunUpcomingRow) -> String {
        var parts: [String] = []
        if row.isCurrent { parts.append("Current") }
        parts.append(row.label)
        if let duration = row.durationSeconds {
            parts.append(Formatters.duration(duration))
        }
        if row.isCurrent && row.isLast {
            parts.append("Last step")
        }
        return parts.joined(separator: ", ")
    }

    private var liveSummary: String {
        let snap = engine.snapshot
        let paused = snap.status == .paused ? "Paused, " : ""
        let next = snap.nextLabel.map { "Next, \($0)." } ?? "Last step."
        let time = Formatters.remaining(snap.remaining)
        return "\(paused)Step \(snap.stepIndex + 1) of \(snap.stepCount), \(snap.label), \(time) remaining. \(next)"
    }

    private func refreshSpokenSummary() {
        let snap = engine.snapshot
        let token = snap.stepIndex * 2 + (snap.status == .paused ? 1 : 0)
        guard token != spokenToken else { return }
        spokenToken = token
        spokenSummary = liveSummary
    }
}

/// Active `.division` from `GeometryProxy.reservedRegions(kind:)`, iOS 27.1+.
/// Wider than tall is tabletop (countdown above the fold, controls below).
/// Taller than wide is book pose and stays on the side-by-side run.
/// On iOS 26 the lookup is skipped and Run stays flat.
private enum DuoFold {
    static func tabletopFrame(in proxy: GeometryProxy) -> CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        return divisionFrame(in: proxy, horizontal: true)
    }

    static func bookFrame(in proxy: GeometryProxy) -> CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        return divisionFrame(in: proxy, horizontal: false)
    }

    @available(iOS 27.1, *)
    private static func divisionFrame(in proxy: GeometryProxy, horizontal: Bool) -> CGRect? {
        guard let region = proxy.reservedRegions(kind: .division).first(where: { $0.isActive }) else {
            return nil
        }
        let rect = region.frame
        if horizontal {
            guard rect.width > rect.height else { return nil }
        } else {
            guard rect.height > rect.width else { return nil }
        }
        return rect
    }
}

private struct RunUpcomingRow: Identifiable {
    var index: Int
    var label: String
    var durationSeconds: Int?
    var isCurrent: Bool
    var isLast: Bool

    var id: Int { index }
}

/// Spoken once per displayed second. The engine ticks at 20 Hz; this view
/// skips updates while the formatted remaining string and pause flag are unchanged.
private struct CountdownReadout: View, Equatable {
    var text: String
    var paused: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 84, weight: .semibold, design: .monospaced))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .accessibilityLabel(paused ? "Paused, \(text) remaining" : "\(text) remaining")
    }
}
