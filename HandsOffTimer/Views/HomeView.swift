import SwiftUI

private enum HomeRoute: Hashable {
    case howItWorks
}

private enum PendingMove: Equatable {
    case select(UUID)
    case newChain
    case howItWorks
    case cancel
}

struct HomeView: View {
    @Environment(ChainStore.self) private var store
    @Environment(ChainEngine.self) private var engine
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var showPermission = false
    @State private var pendingDelete: TimerChain?
    @State private var path: [HomeRoute] = []
    @State private var selection: UUID?
    @State private var revertingSelection = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var pendingMove: PendingMove?
    @State private var showUnsaved = false
    /// Regular-width detail. False after Save, so the column leaves the editor.
    @State private var detailEditing = true
    /// Bumps on a successful split Save. Drives a success haptic.
    @State private var saveFeedback = 0
    /// Set while Start handles the tap, so a selectable row does not steal the editor.
    @State private var selectionIgnoredForStart: UUID?

    var body: some View {
        debugLaunch(homeContainer)
            .sensoryFeedback(.success, trigger: saveFeedback)
            .sheet(isPresented: editorSheetPresented) {
                ChainEditorView(
                    embedInStack: true,
                    showsToolbarSymbols: false,
                    onCancel: { router.closeEditor() },
                    onSave: saveAndCloseSheet
                )
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
            .alert("Save changes to this chain?", isPresented: $showUnsaved) {
                Button("Save") {
                    commitDraft()
                    performPending()
                }
                Button("Discard", role: .destructive) {
                    discardDraft()
                    performPending()
                }
                Button("Cancel", role: .cancel) {
                    pendingMove = nil
                }
            } message: {
                Text("If you don’t save, your edits will be lost.")
            }
            .onAppear {
                noteActiveRunIfNeeded()
                if horizontalSizeClass == .regular {
                    ensureDefaultSelection()
                }
            }
            .onChange(of: horizontalSizeClass) { _, newValue in
                switch newValue {
                case .regular:
                    adoptRegular()
                case .compact:
                    adoptCompact()
                default:
                    break
                }
            }
            .onChange(of: path) { _, newPath in
                // The split detail owns the guide while the list is on screen.
                // The single-column stack (compact, or regular with no chains) uses `path`.
                guard !usesRegularSplit else { return }
                let showing = newPath.contains(.howItWorks)
                if router.showsHowItWorks != showing {
                    router.showsHowItWorks = showing
                }
            }
            .onChange(of: router.showsHowItWorks) { _, showing in
                guard horizontalSizeClass != .regular else { return }
                if showing {
                    if path != [.howItWorks] {
                        path = [.howItWorks]
                    }
                } else if path.contains(.howItWorks) {
                    path = []
                }
            }
            .onChange(of: store.chains) { _, chains in
                if let id = router.selectedChainID, !chains.contains(where: { $0.id == id }) {
                    router.selectedChainID = nil
                    if router.draft?.chainID == id {
                        router.draft = nil
                    }
                }
                if horizontalSizeClass == .regular {
                    ensureDefaultSelection()
                }
            }
            .onChange(of: router.draft == nil) { _, isNil in
                guard isNil, horizontalSizeClass == .regular else { return }
                ensureDefaultSelection()
            }
            .onChange(of: router.selectedChainID) { _, id in
                guard selection != id else { return }
                if usesRegularSplit {
                    revertingSelection = true
                }
                selection = id
            }
    }

    /// Regular width with at least one saved chain uses the side-by-side home.
    /// An empty library keeps today's centered empty state, including on the open display.
    private var usesRegularSplit: Bool {
        horizontalSizeClass == .regular && !store.chains.isEmpty
    }

    private var showsEditorSheet: Bool {
        guard let draft = router.draft else { return false }
        if usesRegularSplit { return false }
        if router.showsHowItWorks { return false }
        // The split's auto-selected chain keeps a clean draft so unfold can
        // restore the detail. That draft must not cover the compact list.
        return draft.isDirty || router.showEditor
    }

    /// Size-class changes dismiss the sheet by flipping this binding. The setter
    /// does not drop the draft — Cancel and Save do that.
    private var editorSheetPresented: Binding<Bool> {
        Binding(
            get: { showsEditorSheet },
            set: { _ in }
        )
    }

    @ViewBuilder
    private var homeContainer: some View {
        if usesRegularSplit {
            regularHome
        } else {
            compactHome
        }
    }

    private var compactHome: some View {
        NavigationStack(path: $path) {
            Group {
                if store.chains.isEmpty {
                    empty
                } else {
                    list
                }
            }
            .navigationTitle("Hands-Off Timer")
            .navigationDestination(for: HomeRoute.self) { _ in
                HowItWorksView()
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        path.append(HomeRoute.howItWorks)
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(WidgetPalette.accent)
                    }
                    .accessibilityLabel("How It Works")
                    .tint(WidgetPalette.accent)

                    Button {
                        router.openNew()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Chain")
                }
            }
        }
    }

    private var regularHome: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            regularSidebar
        } detail: {
            regularDetail
                .navigationSplitViewColumnWidth(min: 300, ideal: 380)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .onAppear {
            if columnVisibility != .all {
                columnVisibility = .all
            }
        }
        .onChange(of: columnVisibility) { _, visibility in
            // A narrow regular window (open portrait, 669 pt) otherwise drops the
            // sidebar and shows it as a dimmed overlay. Keep both columns visible.
            if visibility != .all {
                columnVisibility = .all
            }
        }
    }

    private var regularSidebar: some View {
        List(selection: $selection) {
            ForEach(store.chains) { chain in
                ChainRowView(
                    chain: chain,
                    keepsStartOnOneLine: true,
                    onEdit: { selectChainFromRow(chain.id) },
                    onStart: { start(chain) },
                    onRequestDelete: { pendingDelete = $0 }
                )
                .tag(chain.id)
            }
        }
        .navigationTitle("Hands-Off Timer")
        .navigationBarTitleDisplayMode(.large)
        .listStyle(.insetGrouped)
        .navigationSplitViewColumnWidth(min: 300, ideal: 320, max: 340)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    requestHowItWorks()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(WidgetPalette.accent)
                }
                .accessibilityLabel("How It Works")
                .tint(WidgetPalette.accent)

                Button {
                    requestNewChain()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New Chain")
            }
        }
        .onAppear {
            selectionIgnoredForStart = nil
            revertingSelection = false
            if selection != router.selectedChainID {
                revertingSelection = true
                selection = router.selectedChainID
            }
        }
        .onChange(of: selection) { _, new in
            if revertingSelection {
                revertingSelection = false
                return
            }
            guard let new else { return }
            if selectionIgnoredForStart == new {
                selectionIgnoredForStart = nil
                if let editingID = router.selectedChainID, editingID != new {
                    revertingSelection = true
                    selection = editingID
                }
                return
            }
            selectionIgnoredForStart = nil
            let draft = router.draft
            let leavingDirtyDraft = draft?.isDirty == true && (draft?.chainID != new || draft?.isNew == true)
            if leavingDirtyDraft {
                pendingMove = .select(new)
                showUnsaved = true
                revertingSelection = true
                selection = router.selectedChainID
                return
            }
            showChain(new)
        }
    }

    @ViewBuilder
    private var regularDetail: some View {
        if router.showsHowItWorks {
            NavigationStack {
                HowItWorksView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                router.showsHowItWorks = false
                            } label: {
                                Label("Back", systemImage: "chevron.backward")
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                    }
            }
        } else if detailEditing, router.draft != nil {
            ChainEditorView(
                embedInStack: true,
                showsToolbarSymbols: true,
                fitsWheelsToColumn: true,
                saveRequiresChanges: true,
                onCancel: regularCancel,
                onSave: saveInSplit
            )
        } else if let chain = selectedChain {
            ChainDetailView(chain: chain, onEdit: { beginEditing(chain.id) })
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .onAppear { ensureDefaultSelection() }
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

    /// ContentUnavailableView accepts any height and clips. A compact height
    /// (the open Duo screen) forces a scroll view and asks for the ideal height.
    @ViewBuilder
    private var empty: some View {
        if horizontalSizeClass == .regular {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        emptyContent
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 420)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        } else if verticalSizeClass == .compact {
            ScrollView {
                emptyContent
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            emptyContent
        }
    }

    private var emptyContent: some View {
        ContentUnavailableView {
            Label("No Chains Created", systemImage: "timer")
        } description: {
            Text("Build a sequence of timers that advance on their own. Start from Home — the editor only saves.")
        } actions: {
            VStack(spacing: 12) {
                Button {
                    router.openNew()
                } label: {
                    Text("New Chain")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    path.append(HomeRoute.howItWorks)
                } label: {
                    Text("How it works")
                        .font(.subheadline)
                        .foregroundStyle(WidgetPalette.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func start(_ chain: TimerChain) {
        selectionIgnoredForStart = chain.id
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
        router.noteRun(chain.id)
        router.showRun = true
    }

    private func noteActiveRunIfNeeded() {
        guard engine.snapshot.status == .running || engine.snapshot.status == .paused else { return }
        guard let id = engine.snapshot.chainId else { return }
        router.noteRun(id)
    }

    private func adoptRegular() {
        selectionIgnoredForStart = nil
        if path.contains(.howItWorks) {
            router.showsHowItWorks = true
            // Keep the push on the empty-library stack. The split detail takes over
            // only once a chain list exists.
            if !store.chains.isEmpty {
                path = []
            }
        }
        ensureDefaultSelection()
    }

    private func adoptCompact() {
        selectionIgnoredForStart = nil
        if router.showsHowItWorks {
            if path != [.howItWorks] {
                path = [.howItWorks]
            }
        } else if path.contains(.howItWorks) {
            path = []
        }
        // Folding closes a clean editor and lands on the list. The selected
        // chain id stays, so opening the display restores the same split.
        // A dirty draft stays presented and is not discarded.
        if router.draft?.isDirty == true {
            router.showEditor = true
        } else {
            router.showEditor = false
            router.draft = nil
            router.editing = nil
            router.isNewEditor = false
        }
    }

    private func ensureDefaultSelection() {
        guard horizontalSizeClass == .regular else { return }
        if let draft = router.draft, draft.isNew {
            router.selectedChainID = nil
            return
        }
        if let draft = router.draft, draft.isDirty {
            if store.chain(id: draft.chainID) != nil {
                router.selectedChainID = draft.chainID
                return
            }
            router.draft = nil
        }
        guard !store.chains.isEmpty else {
            router.selectedChainID = nil
            if router.draft != nil {
                router.draft = nil
            }
            return
        }
        let resolved: UUID
        if let id = router.selectedChainID, store.chain(id: id) != nil {
            resolved = id
        } else if let last = router.lastRunChainID, store.chain(id: last) != nil {
            resolved = last
        } else if let first = store.chains.first?.id {
            resolved = first
        } else {
            return
        }
        let needsDraft = router.draft?.chainID != resolved || router.draft == nil || router.draft?.isNew == true
        if detailEditing, needsDraft {
            if let chain = store.chain(id: resolved), router.draft?.isDirty != true {
                router.draft = EditorDraft(chain: chain, isNew: false)
                router.editing = chain
                router.isNewEditor = false
                router.showEditor = false
            }
        }
        router.selectedChainID = resolved
    }

    private var selectedChain: TimerChain? {
        guard let id = router.selectedChainID else { return nil }
        return store.chain(id: id)
    }

    private func selectChainFromRow(_ id: UUID) {
        selectionIgnoredForStart = nil
        if selection == id {
            if !detailEditing {
                beginEditing(id)
                return
            }
            if router.showsHowItWorks {
                if router.draft?.isDirty == true {
                    pendingMove = .select(id)
                    showUnsaved = true
                } else {
                    router.showsHowItWorks = false
                }
            }
            return
        }
        selection = id
    }

    private func showChain(_ id: UUID) {
        beginEditing(id)
    }

    /// Opens the editor for a sidebar tap. Does not set `showEditor`, so an
    /// automatic selection cannot present the compact sheet.
    private func beginEditing(_ id: UUID) {
        router.showsHowItWorks = false
        guard let chain = store.chain(id: id) else { return }
        if router.draft?.chainID != id || router.draft == nil || router.draft?.isNew == true {
            router.draft = EditorDraft(chain: chain, isNew: false)
        }
        router.selectedChainID = id
        router.editing = chain
        router.isNewEditor = false
        router.showEditor = false
        detailEditing = true
    }

    private func requestNewChain() {
        if usesRegularSplit, router.draft?.isDirty == true {
            pendingMove = .newChain
            showUnsaved = true
            return
        }
        detailEditing = true
        router.openNew()
    }

    private func requestHowItWorks() {
        if usesRegularSplit {
            if router.draft?.isDirty == true {
                pendingMove = .howItWorks
                showUnsaved = true
                return
            }
            router.showsHowItWorks = true
            return
        }
        path.append(.howItWorks)
    }

    private func regularCancel() {
        guard let draft = router.draft else { return }
        if draft.isDirty {
            pendingMove = .cancel
            showUnsaved = true
            return
        }
        if draft.isNew {
            router.draft = nil
            router.selectedChainID = nil
            router.showEditor = false
            router.editing = nil
            router.isNewEditor = false
            detailEditing = false
            ensureDefaultSelection()
        }
    }

    /// Split Save: persist, then leave the editor so the detail shows the saved chain.
    private func saveInSplit() {
        guard commitDraft() else { return }
        detailEditing = false
        router.showEditor = false
        saveFeedback += 1
    }

    @discardableResult
    private func commitDraft() -> Bool {
        guard let draft = router.draft else { return false }
        var chain = TimerChain(id: draft.chainID, name: draft.name, steps: draft.steps)
        chain.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.upsert(chain)
        guard let saved = store.chain(id: chain.id) else { return false }
        draft.markSaved(chain: saved)
        router.selectedChainID = saved.id
        router.editing = saved
        router.isNewEditor = false
        router.showEditor = false
        return true
    }

    private func discardDraft() {
        guard let draft = router.draft else { return }
        if draft.isNew {
            router.draft = nil
            router.selectedChainID = nil
            router.editing = nil
            router.isNewEditor = false
            router.showEditor = false
            return
        }
        if let chain = store.chain(id: draft.chainID) {
            draft.markSaved(chain: chain)
            router.editing = chain
        } else {
            router.draft = nil
            router.editing = nil
        }
    }

    private func saveAndCloseSheet() {
        guard commitDraft() else { return }
        if horizontalSizeClass == .regular, !store.chains.isEmpty {
            detailEditing = false
            saveFeedback += 1
            return
        }
        router.draft = nil
        router.showEditor = false
        router.editing = nil
        router.isNewEditor = false
    }

    private func performPending() {
        let move = pendingMove
        pendingMove = nil
        switch move {
        case .select(let id):
            showChain(id)
        case .newChain:
            detailEditing = true
            router.openNew()
        case .howItWorks:
            if router.draft == nil {
                ensureDefaultSelection()
            }
            router.showsHowItWorks = true
        case .cancel:
            if router.draft == nil || router.draft?.isNew == true {
                router.draft = nil
                router.selectedChainID = nil
                ensureDefaultSelection()
            }
        case nil:
            break
        }
    }

    private func debugLaunch<V: View>(_ view: V) -> some View {
        #if DEBUG
        view.onAppear(perform: consumeDebugLaunchArgumentsIfNeeded)
        #else
        view
        #endif
    }

    #if DEBUG
    /// `-autoStartFirstChain` (Debug only): start Home's first row the same way
    /// the Start button does, including the alarm explainer when it is still needed.
    private func consumeDebugLaunchArgumentsIfNeeded() {
        guard !DebugAutoStart.didStart else { return }
        DebugAutoStart.didStart = true
        guard ProcessInfo.processInfo.arguments.contains("-autoStartFirstChain") else { return }
        // Next turn, so HandsOffTimerApp has installed engine hooks and the
        // permission alert is not presented from inside onAppear.
        Task { @MainActor in
            guard engine.snapshot.status != .running, engine.snapshot.status != .paused else { return }
            guard let chain = store.chains.first else { return }
            start(chain)
        }
    }
    #endif
}

#if DEBUG
@MainActor
private enum DebugAutoStart {
    static var didStart = false
}
#endif

/// Saved chain in the open detail column. Not the editor: Save leaves this on screen.
private struct ChainDetailView: View {
    let chain: TimerChain
    var onEdit: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(chain.displayName)
                        .font(.body.weight(.semibold))
                } header: {
                    Text("Name")
                }

                Section("Steps") {
                    ForEach(Array(chain.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .firstTextBaseline) {
                            Text(step.displayLabel(index: index))
                            Spacer(minLength: 12)
                            Text(Formatters.duration(step.durationSeconds))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }

                Section {
                    Text(Formatters.stepSummary(count: chain.steps.count, totalSeconds: chain.totalSeconds))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(chain.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
    }
}

/// Swipe / context menu only request delete. Confirm lives on the parent so it
/// actually appears (row-level confirmationDialog after swipeActions is flaky).
private struct ChainRowView: View {
    let chain: TimerChain
    /// Regular-width sidebar only. Compact rows leave this false and keep today's layout.
    var keepsStartOnOneLine: Bool = false
    let onEdit: () -> Void
    let onStart: () -> Void
    let onRequestDelete: (TimerChain) -> Void

    var body: some View {
        Group {
            if keepsStartOnOneLine {
                wideRow
            } else {
                compactRow
            }
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

    /// Compact and folded rows. Unchanged from the single-column list.
    private var compactRow: some View {
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
            startButton
        }
    }

    /// Open sidebar: Start stays one line; the name uses whatever width is left.
    private var wideRow: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chain.displayName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(Formatters.stepSummary(count: chain.steps.count, totalSeconds: chain.totalSeconds))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button(action: onStart) {
                Label("Start", systemImage: "play.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var startButton: some View {
        Button(action: onStart) {
            Label("Start", systemImage: "play.fill")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .controlSize(.small)
    }
}
