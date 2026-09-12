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
                .onAppear {
                    engine.onNaturalEnd = { _ in
                        Haptics.light()
                    }
                    engine.onSnapshot = { snap in
                        NotificationGateway.shared.sync(snap)
                        LiveActivityController.shared.sync(snap)
                    }
                    NotificationGateway.shared.sync(engine.snapshot)
                    LiveActivityController.shared.sync(engine.snapshot)
                    if engine.snapshot.status == .running || engine.snapshot.status == .paused {
                        router.showRun = true
                    }
                }
        }
    }
}
