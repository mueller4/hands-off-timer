import SwiftUI

struct HomeView: View {
    @Environment(ChainStore.self) private var store
    @Environment(ChainEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @State private var pendingDelete: TimerChain?
    @State private var showPermission = false

    var body: some View {
        NavigationStack {
            Group {
                if store.chains.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle("Chains")
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
            .confirmationDialog(
                "Delete “\(pendingDelete?.displayName ?? "")”?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete chain", role: .destructive) {
                    if let pendingDelete { store.delete(pendingDelete) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This chain will be removed from this device.")
            }
            .alert("Stay in motion", isPresented: $showPermission) {
                Button("Allow") {
                    Task { await startPending(requestPermission: true) }
                }
                Button("Not Now", role: .cancel) {
                    Task { await startPending(requestPermission: false) }
                }
            } message: {
                Text(NotificationGateway.purpose)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(store.chains) { chain in
                HStack(spacing: 12) {
                    Button {
                        router.openEdit(chain)
                    } label: {
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
                    Button {
                        start(chain)
                    } label: {
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
                        pendingDelete = chain
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        router.openEdit(chain)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No chains yet", systemImage: "timer")
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
        Task {
            let status = await NotificationGateway.shared.authorizationStatus()
            if status == .notDetermined && !router.didPromptNotifications {
                showPermission = true
                return
            }
            await startPending(requestPermission: false)
        }
    }

    @MainActor
    private func startPending(requestPermission: Bool) async {
        router.didPromptNotifications = true
        if requestPermission {
            await NotificationGateway.shared.requestAuthorizationIfNeeded()
        }
        guard let chain = router.pendingStart else { return }
        router.pendingStart = nil
        engine.start(chain: chain)
        router.showRun = true
    }
}
