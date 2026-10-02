import Foundation

@MainActor
@Observable
final class AppRouter {
    var editing: TimerChain?
    var isNewEditor = false
    var showEditor = false
    var showRun = false
    var showPermissionExplainer = false
    var pendingStart: TimerChain?
    var didPromptAlarms = false

    func openNew() {
        editing = TimerChain()
        isNewEditor = true
        showEditor = true
    }

    func openEdit(_ chain: TimerChain) {
        editing = chain
        isNewEditor = false
        showEditor = true
    }

    func closeEditor() {
        showEditor = false
        editing = nil
    }
}
