import SwiftUI

struct ChainEditorView: View {
    var embedInStack: Bool = true
    /// Icon and title so Cancel and Save still appear if the detail bar is vertical.
    var showsToolbarSymbols: Bool = false
    var onCancel: () -> Void
    var onSave: () -> Void

    @Environment(AppRouter.self) private var router

    var body: some View {
        if let draft = router.draft {
            EditorForm(
                draft: draft,
                embedInStack: embedInStack,
                showsToolbarSymbols: showsToolbarSymbols,
                onCancel: onCancel,
                onSave: onSave
            )
            .id(ObjectIdentifier(draft))
        }
    }
}

private struct EditorForm: View {
    @Bindable var draft: EditorDraft
    var embedInStack: Bool
    var showsToolbarSymbols: Bool
    var onCancel: () -> Void
    var onSave: () -> Void

    private var savable: Bool {
        TimerChain(id: draft.chainID, name: draft.name, steps: draft.steps).isSavable
    }

    var body: some View {
        if embedInStack {
            NavigationStack { form }
                .interactiveDismissDisabled()
        } else {
            form
        }
    }

    private var form: some View {
        List {
            Section {
                TextField(TimerChain.defaultName, text: $draft.name)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Name")
            } footer: {
                Text("Optional. Empty names save as Untitled chain.")
            }

            Section("Steps") {
                ForEach($draft.steps) { $step in
                    StepEditorRow(
                        step: $step,
                        index: draft.steps.firstIndex(where: { $0.id == step.id }) ?? 0
                    )
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            }

            Section {
                Button {
                    draft.steps.append(ChainStep())
                } label: {
                    Label("Add Step", systemImage: "plus")
                }
            }

            Section {
                EmptyView()
            } footer: {
                if draft.steps.count < TimerChain.minSteps {
                    Text("Add at least two steps to save.")
                } else if draft.steps.contains(where: { $0.durationSeconds < TimerChain.minStepSeconds }) {
                    Text("Each step needs at least 1 second.")
                } else {
                    Text("Start lives on Home. Save here, then run the chain from the list.")
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(draft.isNew ? "New Chain" : "Edit Chain")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onCancel) {
                    if showsToolbarSymbols {
                        Label("Cancel", systemImage: "xmark")
                            .labelStyle(.titleAndIcon)
                    } else {
                        Text("Cancel")
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(action: onSave) {
                    if showsToolbarSymbols {
                        Label("Save", systemImage: "checkmark")
                            .labelStyle(.titleAndIcon)
                    } else {
                        Text("Save")
                    }
                }
                .disabled(!savable)
                .fontWeight(.semibold)
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        draft.steps.move(fromOffsets: source, toOffset: destination)
    }

    private func delete(at offsets: IndexSet) {
        draft.steps.remove(atOffsets: offsets)
    }
}

struct StepEditorRow: View {
    @Binding var step: ChainStep
    var index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Step \(index + 1)", text: $step.label)
            HStack(spacing: 0) {
                Picker("Minutes", selection: minutesBinding) {
                    ForEach(0...99, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .labelsHidden()
                .accessibilityLabel("Minutes")

                Text("min")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)

                Picker("Seconds", selection: secondsBinding) {
                    ForEach(0...59, id: \.self) { value in
                        Text(String(format: "%02d", value)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .labelsHidden()
                .accessibilityLabel("Seconds")

                Text("sec")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .leading)
            }
            .frame(height: 120)
            .clipped()
        }
        .padding(.vertical, 4)
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { min(99, step.durationSeconds / 60) },
            set: { minutes in
                applyDuration(minutes: max(0, minutes), seconds: step.durationSeconds % 60)
            }
        )
    }

    private var secondsBinding: Binding<Int> {
        Binding(
            get: { step.durationSeconds % 60 },
            set: { seconds in
                applyDuration(
                    minutes: min(99, step.durationSeconds / 60),
                    seconds: min(59, max(0, seconds))
                )
            }
        )
    }

    private func applyDuration(minutes: Int, seconds: Int) {
        let total = minutes * 60 + seconds
        step.durationSeconds = max(TimerChain.minStepSeconds, total)
    }
}
