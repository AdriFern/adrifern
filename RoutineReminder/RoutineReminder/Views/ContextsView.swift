import SwiftUI
import SwiftData

/// "People & Pets" — contexts with presence patterns (e.g. a daughter on
/// alternating custody weeks, or a shared pet). Routines linked to a context
/// only remind you on the days that context is active.
struct ContextsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ContextTag.createdAt) private var contexts: [ContextTag]
    @Query private var routines: [Routine]

    @State private var editingContext: ContextTag?
    @State private var creatingNew = false

    var body: some View {
        NavigationStack {
            Group {
                if contexts.isEmpty {
                    EmptyStateView(symbol: "figure.2.and.child.holdinghands",
                                   title: "No people or pets yet",
                                   message: "Add someone with a week pattern — like a child or pet on alternating custody weeks — and link routines to them so reminders only fire on the right weeks.")
                } else {
                    List {
                        ForEach(contexts) { context in
                            ContextRow(context: context,
                                       linkedCount: routines.filter { $0.contextID == context.id }.count)
                                .contentShape(Rectangle())
                                .onTapGesture { editingContext = context }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("People & Pets")
            .toolbar {
                Button { creatingNew = true } label: { Image(systemName: "plus") }
            }
            .sheet(isPresented: $creatingNew) { ContextEditorView(context: nil) }
            .sheet(item: $editingContext) { context in
                ContextEditorView(context: context)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let context = contexts[index]
            // Unlink any routines pointing at this context so they become "always".
            for routine in routines where routine.contextID == context.id {
                routine.contextID = nil
            }
            modelContext.delete(context)
        }
        try? modelContext.save()
        NotificationManager.shared.syncAll()
    }
}

private struct ContextRow: View {
    let context: ContextTag
    let linkedCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: context.symbol)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(Palette.color(context.colorName).gradient, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(context.name)
                Text(context.pattern.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if linkedCount > 0 {
                    Text("\(linkedCount) linked routine\(linkedCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if Scheduler.isContextActive(context.pattern, on: .now) {
                Text("With you now")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Editor

struct ContextEditorView: View {
    let context: ContextTag?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var symbol = "person.fill"
    @State private var colorName = "purple"
    @State private var pattern = PresencePattern()
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Who?") {
                    TextField("Name (e.g. Emma, Rocky)", text: $name)
                    SymbolColorPicker(symbol: $symbol, colorName: $colorName, symbols: SymbolChoices.context)
                }
                Section("When are they with you?") {
                    Picker("Pattern", selection: $pattern.kind) {
                        ForEach(PresenceKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                switch pattern.kind {
                case .alternatingWeeks:
                    Section {
                        Stepper("Weeks with you: \(pattern.weeksOn)", value: $pattern.weeksOn, in: 1...4)
                        Stepper("Weeks away: \(pattern.weeksOff)", value: $pattern.weeksOff, in: 1...4)
                        DatePicker("Any day of a week they're with you",
                                   selection: $pattern.anchorDate,
                                   displayedComponents: .date)
                    } footer: {
                        Text("Pick any date inside a week they are (or will be) with you — the rotation is calculated from that week.")
                    }
                    Section("Upcoming weeks") {
                        ForEach(Array(Scheduler.weekPreview(for: pattern).enumerated()), id: \.offset) { _, week in
                            HStack {
                                Text(week.range)
                                Spacer()
                                Text(week.active ? "With you" : "Away")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(week.active ? .green : .secondary)
                            }
                        }
                    }
                case .weekdays:
                    Section("Which days?") {
                        WeekdayPicker(selection: $pattern.weekdays)
                    }
                case .always:
                    EmptyView()
                }
            }
            .navigationTitle(context == nil ? "New Person or Pet" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: loadDraft)
        }
    }

    private func loadDraft() {
        guard !loaded, let context else { return }
        loaded = true
        name = context.name
        symbol = context.symbol
        colorName = context.colorName
        pattern = context.pattern
    }

    private func save() {
        let target: ContextTag
        if let context {
            target = context
        } else {
            target = ContextTag(name: name)
            modelContext.insert(target)
        }
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.symbol = symbol
        target.colorName = colorName
        target.pattern = pattern
        try? modelContext.save()
        NotificationManager.shared.syncAll()
        dismiss()
    }
}
