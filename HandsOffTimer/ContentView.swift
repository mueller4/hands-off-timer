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
                // Notification tap: open Run on the already-advanced engine state.
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
