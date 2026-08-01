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
    @State private var pendingDeletion: ContextTag?

    var body: some View {
        NavigationStack {
            Group {
                if contexts.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "No people or pets yet"), systemImage: "figure.2.and.child.holdinghands")
                    } description: {
                        Text(String(localized: "Add someone with a week pattern — like a child or pet on alternating custody weeks — and link routines to them so reminders only fire on the right weeks."))
                    } actions: {
                        Button(String(localized: "Add Person or Pet")) { creatingNew = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(contexts) { context in
                            Button {
                                editingContext = context
                            } label: {
                                ContextRow(context: context,
                                           linkedCount: routines.filter { $0.contextID == context.id }.count)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            if let index = offsets.first {
                                pendingDeletion = contexts[index]
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "People & Pets"))
            .toolbar {
                Button { creatingNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel(Text(String(localized: "Add person or pet")))
            }
            .sheet(isPresented: $creatingNew) { ContextEditorView(context: nil) }
            .sheet(item: $editingContext) { context in
                ContextEditorView(context: context)
            }
            .confirmationDialog(
                deletionTitle,
                isPresented: Binding(get: { pendingDeletion != nil },
                                     set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button(String(localized: "Delete and keep routines (they'll repeat on all days)"), role: .destructive) {
                    if let context = pendingDeletion { delete(context, deleteRoutines: false) }
                }
                Button(String(localized: "Delete with their routines"), role: .destructive) {
                    if let context = pendingDeletion { delete(context, deleteRoutines: true) }
                }
                Button(String(localized: "Cancel"), role: .cancel) { pendingDeletion = nil }
            }
        }
    }

    private var deletionTitle: String {
        guard let context = pendingDeletion else { return "" }
        let linked = routines.filter { $0.contextID == context.id }.count
        return linked > 0
            ? String(localized: "Delete \(context.name)? \(linked) linked routine(s) would then repeat on ALL days.")
            : String(localized: "Delete \(context.name)?")
    }

    private func delete(_ context: ContextTag, deleteRoutines: Bool) {
        for routine in routines where routine.contextID == context.id {
            if deleteRoutines {
                CompletionStore.deleteRecords(for: routine.id, in: modelContext)
                modelContext.delete(routine)
            } else {
                routine.contextID = nil
            }
        }
        modelContext.delete(context)
        try? modelContext.save()
        NotificationManager.shared.syncAll()
        pendingDeletion = nil
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
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(context.name)
                Text(context.pattern.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if linkedCount > 0 {
                    Text(String(localized: "\(linkedCount) linked routine(s)"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            if Scheduler.isContextActive(context.pattern, on: .now) {
                Text(String(localized: "With you now"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15), in: Capsule())
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
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

    private var weekdaySymbols: [String] { Calendar.current.weekdaySymbols }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Who?")) {
                    TextField(String(localized: "Name (e.g. Emma, Rocky)"), text: $name)
                    SymbolColorPicker(symbol: $symbol, colorName: $colorName, symbols: SymbolChoices.context)
                }
                Section(String(localized: "When are they with you?")) {
                    Picker(String(localized: "Pattern"), selection: $pattern.kind) {
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
                        Stepper(String(localized: "Weeks with you: \(pattern.weeksOn)"), value: $pattern.weeksOn, in: 1...4)
                        Stepper(String(localized: "Weeks away: \(pattern.weeksOff)"), value: $pattern.weeksOff, in: 1...4)
                        Picker(String(localized: "Weeks switch on"), selection: $pattern.handoffWeekday) {
                            ForEach(1...7, id: \.self) { weekday in
                                Text(weekdaySymbols[weekday - 1]).tag(weekday)
                            }
                        }
                        DatePicker(String(localized: "Any day of a week they're with you"),
                                   selection: $pattern.anchorDate,
                                   displayedComponents: .date)
                    } footer: {
                        Text(String(localized: "Pick the handoff day (many custody schedules switch on a Friday or Monday) and any date inside a week they are — or will be — with you. The rotation is calculated from that week, forever."))
                    }
                    Section(String(localized: "Upcoming weeks")) {
                        ForEach(Array(Scheduler.weekPreview(for: pattern).enumerated()), id: \.offset) { _, week in
                            HStack {
                                Text(week.range)
                                Spacer()
                                Text(week.active ? String(localized: "With you") : String(localized: "Away"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(week.active ? .green : .secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                case .weekdays:
                    Section(String(localized: "Which days?")) {
                        WeekdayPicker(selection: $pattern.weekdays)
                    }
                case .always:
                    EmptyView()
                }
            }
            .navigationTitle(context == nil ? String(localized: "New Person or Pet") : String(localized: "Edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save"), action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                                  || (pattern.kind == .weekdays && pattern.weekdays.isEmpty))
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
