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
                    EmptyStateView(symbol: "list.bullet.rectangle.portrait",
                                   title: "No routines yet",
                                   message: "Tap + for the step-by-step setup, or the chat bubble to just describe what you need.")
                } else {
                    List {
                        ForEach(routines) { routine in
                            RoutineListRow(routine: routine, context: contexts.first { $0.id == routine.contextID })
                                .contentShape(Rectangle())
                                .onTapGesture { editingRoutine = routine }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showingQuickAdd = true } label: { Image(systemName: "text.bubble") }
                    Button { showingWizard = true } label: { Image(systemName: "plus") }
                }
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
            modelContext.delete(routines[index])
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
                    }
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
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
