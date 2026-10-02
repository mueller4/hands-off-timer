import SwiftUI

struct ContentView: View {
    @Environment(ChainStore.self) private var store
    @Environment(ChainEngine.self) private var engine
    @Environment(AppRouter.self) private var router

    var body: some View {
        HomeView()
            .sheet(isPresented: editorBinding) {
                if let draft = router.editing {
                    ChainEditorView(isNew: router.isNewEditor, original: draft)
                }
            }
            .fullScreenCover(isPresented: runBinding) {
                RunView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .handsOffOpenRun)) { _ in
                // Island / deep-link / leftover notification tap: open Run on the
                // already-advanced engine state. AlarmKit OK does not post this.
                // Never pause, stop, reset, or delay.
                if engine.snapshot.status == .running || engine.snapshot.status == .paused {
                    router.showRun = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                engine.tick()
                if engine.snapshot.status == .running || engine.snapshot.status == .paused {
                    router.showRun = true
                }
            }
            .onChange(of: store.chains) { _, chains in
                HomeWidgetPublisher.publish(chains: chains, snapshot: engine.snapshot)
            }
    }

    private var editorBinding: Binding<Bool> {
        Binding(
            get: { router.showEditor },
            set: { router.showEditor = $0 }
        )
    }

    private var runBinding: Binding<Bool> {
        Binding(
            get: { router.showRun },
            set: { router.showRun = $0 }
        )
    }
}
