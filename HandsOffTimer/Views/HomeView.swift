import SwiftUI

struct HomeView: View {
    @Environment(ChainStore.self) private var store
    @Environment(ChainEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @State private var showPermission = false
    @State private var pendingDelete: TimerChain?

    var body: some View {
        NavigationStack {
            Group {
                if store.chains.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle("Hands-Off Timer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.openNew()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Chain")
                }
            }
            .alert("Stay in motion", isPresented: $showPermission) {
                Button("Allow") {
                    Task { await startPending(requestPermission: true) }
                }
                Button("Not Now", role: .cancel) {
                    Task { await startPending(requestPermission: false) }
                }
            } message: {
                Text(AlarmKitGateway.purpose)
            }
            .alert(
                "Delete “\(pendingDelete?.displayName ?? "")”?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                )
            ) {
                Button("Delete chain", role: .destructive) {
                    if let pendingDelete { store.delete(pendingDelete) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This chain will be removed from this device.")
            }
        }
    }

    private var list: some View {
        List {
            ForEach(store.chains) { chain in
                ChainRowView(
                    chain: chain,
                    onEdit: { router.openEdit(chain) },
                    onStart: { start(chain) },
                    onRequestDelete: { pendingDelete = $0 }
                )
            }
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No Chains Created", systemImage: "timer")
        } description: {
            Text("Build a sequence of timers that advance on their own. Start from Home — the editor only saves.")
        } actions: {
            Button {
                router.openNew()
            } label: {
                Text("New Chain")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func start(_ chain: TimerChain) {
        router.pendingStart = chain
        if AlarmKitGateway.shared.needsAuthorizationPrompt && !router.didPromptAlarms {
            showPermission = true
            return
        }
        Task { await startPending(requestPermission: false) }
    }

    @MainActor
    private func startPending(requestPermission: Bool) async {
        router.didPromptAlarms = true
        if requestPermission {
            await AlarmKitGateway.shared.requestAuthorizationIfNeeded()
        }
        guard let chain = router.pendingStart else { return }
        router.pendingStart = nil
        // Same teardown as Stop: a prior run may still be alerting (user didn't OK,
        // or force-quit). New Start must not leave those alarms or a stale Island.
        await LiveActivityController.shared.endForRun()
        AlarmKitGateway.shared.cancelAllForRun()
        engine.start(chain: chain)
        router.showRun = true
    }
}

/// Swipe / context menu only request delete. Confirm lives on the parent so it
/// actually appears (row-level confirmationDialog after swipeActions is flaky).
private struct ChainRowView: View {
    let chain: TimerChain
    let onEdit: () -> Void
    let onStart: () -> Void
    let onRequestDelete: (TimerChain) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chain.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(Formatters.stepSummary(count: chain.steps.count, totalSeconds: chain.totalSeconds))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 8)
            Button(action: onStart) {
                Label("Start", systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onRequestDelete(chain)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onRequestDelete(chain)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
