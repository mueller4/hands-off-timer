import SwiftUI

struct ChainEditorView: View {
    @Environment(ChainStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    @State private var name: String
    @State private var steps: [ChainStep]

    init(isNew: Bool, original: TimerChain) {
        self.isNew = isNew
        _name = State(initialValue: original.name)
        _steps = State(initialValue: original.steps)
        self.originalID = original.id
    }

    private let originalID: UUID

    private var savable: Bool {
        TimerChain(id: originalID, name: name, steps: steps).isSavable
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(TimerChain.defaultName, text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                } footer: {
                    Text("Optional. Empty names save as Untitled chain.")
                }

                Section("Steps") {
                    ForEach($steps) { $step in
                        StepEditorRow(
                            step: $step,
                            index: steps.firstIndex(where: { $0.id == step.id }) ?? 0
                        )
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }

                Section {
                    Button {
                        steps.append(ChainStep())
                    } label: {
                        Label("Add Step", systemImage: "plus")
                    }
                }

                Section {
                    EmptyView()
                } footer: {
                    if steps.count < TimerChain.minSteps {
                        Text("Add at least two steps to save.")
                    } else if steps.contains(where: { $0.durationSeconds < TimerChain.minStepSeconds }) {
                        Text("Each step needs at least 1 second.")
                    } else {
                        Text("Start lives on Home. Save here, then run the chain from the list.")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(isNew ? "New Chain" : "Edit Chain")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        router.closeEditor()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!savable)
                        .fontWeight(.semibold)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func move(from source: IndexSet, to destination: Int) {
        steps.move(fromOffsets: source, toOffset: destination)
    }

    private func delete(at offsets: IndexSet) {
        steps.remove(atOffsets: offsets)
    }

    private func save() {
        var chain = TimerChain(id: originalID, name: name, steps: steps)
        chain.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.upsert(chain)
        router.closeEditor()
        dismiss()
    }
}

struct StepEditorRow: View {
    @Binding var step: ChainStep
    var index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Step \(index + 1)", text: $step.label)
            HStack {
                Stepper(value: $step.durationSeconds, in: 1...10_800, step: 15) {
                    Text(Formatters.duration(step.durationSeconds))
                        .font(.body.monospacedDigit())
                }
            }
            HStack(spacing: 12) {
                labeledNumber("m", value: minutesBinding, range: 0...180)
                labeledNumber("s", value: secondsBinding, range: 0...59)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { step.durationSeconds / 60 },
            set: { minutes in
                let seconds = step.durationSeconds % 60
                step.durationSeconds = max(1, minutes * 60 + seconds)
            }
        )
    }

    private var secondsBinding: Binding<Int> {
        Binding(
            get: { step.durationSeconds % 60 },
            set: { seconds in
                let minutes = step.durationSeconds / 60
                step.durationSeconds = max(1, minutes * 60 + seconds)
            }
        )
    }

    private func labeledNumber(_ unit: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 4) {
            TextField(unit, value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}
