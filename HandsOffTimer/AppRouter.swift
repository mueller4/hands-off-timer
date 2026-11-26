import Foundation

/// Editor fields live on the router so a fold, unfold, or size-class change
/// can swap the sheet for the split detail without dropping unsaved text.
@MainActor
@Observable
final class EditorDraft {
    var chainID: UUID
    var isNew: Bool
    var name: String
    var steps: [ChainStep]
    private var savedName: String
    private var savedSteps: [ChainStep]

    init(chain: TimerChain, isNew: Bool) {
        chainID = chain.id
        self.isNew = isNew
        name = chain.name
        steps = chain.steps
        savedName = chain.name
        savedSteps = chain.steps
    }

    var isDirty: Bool {
        name != savedName || steps != savedSteps
    }

    func markSaved(chain: TimerChain) {
        chainID = chain.id
        isNew = false
        name = chain.name
        steps = chain.steps
        savedName = chain.name
        savedSteps = chain.steps
    }
}

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

    /// Chain highlighted in the regular-width split. Survives fold and unfold.
    var selectedChainID: UUID?
    /// In-progress editor. Nil when the compact sheet is closed and the split has nothing loaded.
    var draft: EditorDraft?
    /// How It Works is showing. On a regular-width window it occupies the detail column.
    var showsHowItWorks = false
    /// Regular-width detail is the editor. False after Save or Cancel, which shows the saved chain.
    var isEditingDetail = true
    /// Chain that was selected before New Chain, so Cancel can return to it.
    var selectionBeforeNew: UUID?
    /// Cancel on a new chain with nothing underneath. Don't auto-select another chain.
    var holdEmptySelection = false
    /// Most recently started chain. Nil until something has run.
    private(set) var lastRunChainID: UUID?

    private static let lastRunDefaultsKey = "handsOff.lastRunChainID"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.lastRunDefaultsKey) {
            lastRunChainID = UUID(uuidString: raw)
        }
        if lastRunChainID == nil {
            lastRunChainID = HomeWidgetDisk.load()?.lastStartedChainID
        }
    }

    func noteRun(_ chainID: UUID) {
        lastRunChainID = chainID
        let key = Self.lastRunDefaultsKey
        if UserDefaults.standard.string(forKey: key) != chainID.uuidString {
            UserDefaults.standard.set(chainID.uuidString, forKey: key)
        }
    }

    func openNew() {
        if let selectedChainID {
            selectionBeforeNew = selectedChainID
        }
        holdEmptySelection = false
        let chain = TimerChain()
        draft = EditorDraft(chain: chain, isNew: true)
        editing = chain
        isNewEditor = true
        showEditor = true
        selectedChainID = nil
        showsHowItWorks = false
        isEditingDetail = true
    }

    func openEdit(_ chain: TimerChain) {
        draft = EditorDraft(chain: chain, isNew: false)
        editing = chain
        isNewEditor = false
        showEditor = true
        selectedChainID = chain.id
        showsHowItWorks = false
        isEditingDetail = true
        holdEmptySelection = false
    }

    func closeEditor() {
        showEditor = false
        editing = nil
        isNewEditor = false
        draft = nil
        showsHowItWorks = false
    }

    /// Discard the open detail draft and leave the editor. Existing chains keep
    /// their selection so the read-only detail can show the saved chain. A new
    /// chain returns to the selection from before New Chain, or to no selection.
    func cancelEditing() {
        let wasNew = draft?.isNew == true
        let restore = selectionBeforeNew
        showEditor = false
        editing = nil
        isNewEditor = false
        draft = nil
        selectionBeforeNew = nil
        isEditingDetail = false
        if wasNew {
            selectedChainID = restore
            holdEmptySelection = restore == nil
        }
    }
}
