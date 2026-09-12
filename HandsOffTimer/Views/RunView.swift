import SwiftUI

struct RunView: View {
    @Environment(ChainEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var confirmStop = false
    @State private var completeTask: Task<Void, Never>?

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
                engine.stop()
                router.showRun = false
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The remaining steps will not run.")
        }
        .onChange(of: engine.snapshot.status) { _, status in
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
        .onAppear {
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
            Text(Formatters.remaining(engine.snapshot.remaining))
                .font(.system(size: 84, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 16)
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
}
