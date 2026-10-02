import SwiftUI

@main
struct HandsOffTimerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = ChainStore()
    @State private var engine = ChainEngine()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(engine)
                .environment(router)
                .onOpenURL { url in
                    openWidgetLink(url)
                }
                .onAppear {
                    engine.onNaturalEnd = { event in
                        // Promote the firing alarm so snapshot sync does not cancel it.
                        // Engine already advanced; this is output-only.
                        AlarmKitGateway.shared.noteNaturalEnd(event)
                        // Light haptic when foregrounded only (BUG-2). Not Silent-gated.
                        // AlarmKit sound is independent and stays `.default`.
                        if UIApplication.shared.applicationState == .active {
                            Haptics.light()
                        }
                    }
                    engine.onSnapshot = { snap in
                        AlarmKitGateway.shared.sync(snap)
                        LiveActivityController.shared.sync(snap)
                        HomeWidgetPublisher.publish(chains: store.chains, snapshot: snap)
                    }
                    AlarmKitGateway.shared.sync(engine.snapshot)
                    LiveActivityController.shared.sync(engine.snapshot)
                    HomeWidgetPublisher.publish(chains: store.chains, snapshot: engine.snapshot)
                    if engine.snapshot.status == .running || engine.snapshot.status == .paused {
                        router.showRun = true
                    }
                }
        }
    }

    /// Widget taps. Empty opens Home (New Chain when the list is empty).
    /// Idle opens the Home chain list — no per-chain scroll or highlight.
    /// Running matches an Island tap. Does not pause, skip, stop, or dismiss AlarmKit.
    private func openWidgetLink(_ url: URL) {
        guard let destination = HomeWidgetLink.destination(from: url) else { return }
        switch destination {
        case .run:
            NotificationCenter.default.post(name: .handsOffOpenRun, object: nil)
            if engine.snapshot.status == .running || engine.snapshot.status == .paused {
                router.showRun = true
            }
        case .home:
            router.closeEditor()
            if engine.snapshot.status != .running && engine.snapshot.status != .paused {
                router.showRun = false
            }
            if store.chains.isEmpty {
                router.openNew()
            }
        }
    }
}
