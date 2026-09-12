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
                    engine.onNaturalEnd = { event in
                        // Promote the firing alarm so snapshot sync does not cancel it.
                        // Engine already advanced; this is output-only.
                        AlarmKitGateway.shared.noteNaturalEnd(event)
                        Haptics.light()
                    }
                    engine.onSnapshot = { snap in
                        AlarmKitGateway.shared.sync(snap)
                        LiveActivityController.shared.sync(snap)
                    }
                    AlarmKitGateway.shared.sync(engine.snapshot)
                    LiveActivityController.shared.sync(engine.snapshot)
                    if engine.snapshot.status == .running || engine.snapshot.status == .paused {
                        router.showRun = true
                    }
                }
        }
    }
}
