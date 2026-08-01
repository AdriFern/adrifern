import SwiftUI
import SwiftData

struct RoutinesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Query private var contexts: [ContextTag]

    @State private var editingRoutine: Routine?
    @State private var showingWizard = false
    @State private var showingQuickAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "No routines yet"), systemImage: "list.bullet.rectangle.portrait")
                    } description: {
                        Text(String(localized: "Set one up step by step, or just describe it in your own words."))
                    } actions: {
                        Button(String(localized: "New Routine")) { showingWizard = true }
                            .buttonStyle(.borderedProminent)
                        Button {
                            showingQuickAdd = true
                        } label: {
                            Label(String(localized: "Quick Add — just type it"), systemImage: "sparkles")
                        }
                    }
                } else {
                    List {
                        ForEach(routines) { routine in
                            Button {
                                editingRoutine = routine
                            } label: {
                                RoutineListRow(routine: routine, context: contexts.first { $0.id == routine.contextID })
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle(String(localized: "Routines"))
            .toolbar {
                Menu {
                    Button {
                        showingWizard = true
                    } label: {
                        Label(String(localized: "New Routine…"), systemImage: "list.bullet.rectangle.portrait")
                    }
                    Button {
                        showingQuickAdd = true
                    } label: {
                        Label(String(localized: "Quick Add — just type it"), systemImage: "sparkles")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(String(localized: "Add")))
            }
            .sheet(isPresented: $showingWizard) { RoutineEditorView(routine: nil) }
            .sheet(isPresented: $showingQuickAdd) { QuickAddView() }
            .sheet(item: $editingRoutine) { routine in
                RoutineEditorView(routine: routine)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let routine = routines[index]
            // Completion history has no cascading relationship — clean it up
            // explicitly so the store never accumulates unreachable records.
            CompletionStore.deleteRecords(for: routine.id, in: modelContext)
            modelContext.delete(routine)
        }
        try? modelContext.save()
        NotificationManager.shared.syncAll()
    }
}

struct RoutineListRow: View {
    @Bindable var routine: Routine
    let context: ContextTag?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: routine.symbol)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Palette.color(routine.colorName).gradient, in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(routine.title)
                    .foregroundStyle(routine.isEnabled ? .primary : .secondary)
                Text(routine.schedule.summary(times: routine.timesMinutes))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Label(routine.alertMode.label, systemImage: routine.alertMode.symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let context {
                        ContextChip(context: context)
                    }
                    if !routine.items.isEmpty {
                        Label("\(routine.items.count)", systemImage: "checklist")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text(String(localized: "\(routine.items.count) checklist steps")))
                    }
                }
            }
            Spacer()
            Toggle(String(localized: "Enabled"), isOn: Binding(
                get: { routine.isEnabled },
                set: { newValue in
                    routine.isEnabled = newValue
                    NotificationManager.shared.syncAll()
                }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}
