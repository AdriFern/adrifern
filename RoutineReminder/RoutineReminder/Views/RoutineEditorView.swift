import SwiftUI
import SwiftData

/// A pre-filled draft (e.g. handed off from Quick Add's "Refine" button).
struct RoutineDraft {
    var title = ""
    var notes = ""
    var symbol = "checklist"
    var colorName = "blue"
    var contextID: UUID?
    var schedule = Schedule()
    var times: [Int] = [9 * 60]
    var alertMode: AlertMode = .notification
    var checklist: [String] = []
}

/// Multi-step wizard for creating a routine; editing an existing routine gets
/// the same sections with Save available from any step.
/// 1. What — title, icon, who it's for
/// 2. When — recurrence pattern and start date
/// 3. Alerts — times of day and notification/alarm mode
/// 4. Checklist — optional sub-steps to tick off
struct RoutineEditorView: View {
    let routine: Routine?
    var draft: RoutineDraft?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var notifications = NotificationManager.shared
    @Query(sort: \ContextTag.createdAt) private var contexts: [ContextTag]

    private enum Step: Int, CaseIterable {
        case what, when, alerts, checklist

        var title: String {
            switch self {
            case .what: return String(localized: "What")
            case .when: return String(localized: "When")
            case .alerts: return String(localized: "Alerts")
            case .checklist: return String(localized: "Checklist")
            }
        }
    }

    /// Stable-identity rows: index-based ForEach + bindings + onDelete is a
    /// known SwiftUI crash pattern, so times and checklist entries carry UUIDs.
    private struct TimeRow: Identifiable {
        let id = UUID()
        var minutes: Int
    }

    private struct ItemRow: Identifiable {
        let id: UUID          // matches an existing ChecklistItem.id when editing
        var title: String
        let isExisting: Bool
    }

    @State private var step: Step = .what

    // Draft state
    @State private var title = ""
    @State private var notes = ""
    @State private var symbol = "checklist"
    @State private var colorName = "blue"
    @State private var contextID: UUID?
    @State private var schedule = Schedule()
    @State private var timeRows: [TimeRow] = [TimeRow(minutes: 9 * 60)]
    @State private var alertMode: AlertMode = .notification
    @State private var itemRows: [ItemRow] = []
    @State private var newItemText = ""
    @State private var hasEndDate = false
    @State private var loaded = false
    @State private var saveFailed = false

    private var isEditing: Bool { routine != nil }

    private var scheduleIsValid: Bool {
        switch schedule.kind {
        case .weekly: return !schedule.weekdays.isEmpty
        case .monthly: return !schedule.monthDays.isEmpty
        default: return true
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && scheduleIsValid
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                Form {
                    switch step {
                    case .what: whatStep
                    case .when: whenStep
                    case .alerts: alertsStep
                    case .checklist: checklistStep
                    }
                }
                footer
            }
            .navigationTitle(isEditing ? String(localized: "Edit Routine") : String(localized: "New Routine"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                if isEditing {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "Save"), action: save)
                            .disabled(!canSave)
                    }
                }
            }
            .onAppear(perform: loadDraft)
            .alert(String(localized: "Couldn't save"), isPresented: $saveFailed) {
                Button(String(localized: "OK"), role: .cancel) {}
            } message: {
                Text(String(localized: "Something went wrong saving this routine. Please try again."))
            }
        }
    }

    // MARK: Steps UI

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Button {
                    withAnimation { step = s }
                } label: {
                    VStack(spacing: 4) {
                        Text(s.title)
                            .font(.caption2.weight(s == step ? .bold : .regular))
                            .foregroundStyle(s == step ? settings.theme.accent : .secondary)
                        Capsule()
                            .fill(s.rawValue <= step.rawValue ? settings.theme.accent : Color(.systemGray4))
                            .frame(height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(String(localized: "Step: \(s.title)")))
                .accessibilityAddTraits(s == step ? [.isSelected] : [])
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    @ViewBuilder private var whatStep: some View {
        Section(String(localized: "What do you need to remember?")) {
            TextField(String(localized: "Title (e.g. Take my pills)"), text: $title)
            TextField(String(localized: "Notes (optional)"), text: $notes, axis: .vertical)
        }
        Section(String(localized: "Look")) {
            SymbolColorPicker(symbol: $symbol, colorName: $colorName, symbols: SymbolChoices.routine)
        }
        Section {
            Picker(String(localized: "Who is this for?"), selection: $contextID) {
                Text(String(localized: "Me / always")).tag(UUID?.none)
                ForEach(contexts) { context in
                    Label(context.name, systemImage: context.symbol).tag(UUID?.some(context.id))
                }
            }
        } footer: {
            if contexts.isEmpty {
                Text(String(localized: "Add people or pets with week patterns in the People & Pets section — then routines linked to them only remind you on the days they're with you."))
            } else {
                Text(String(localized: "Linked routines only remind you on days that person or pet is with you."))
            }
        }
    }

    @ViewBuilder private var whenStep: some View {
        Section(String(localized: "How often?")) {
            Picker(String(localized: "Repeat"), selection: $schedule.kind) {
                ForEach(ScheduleKind.allCases) { kind in
                    Label(kind.label, systemImage: kind.symbol).tag(kind)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
        switch schedule.kind {
        case .everyNDays:
            Section {
                Stepper(value: $schedule.interval, in: 2...90) {
                    Text(schedule.interval == 2
                         ? String(localized: "Every other day")
                         : String(localized: "Every \(schedule.interval) days"))
                }
            } footer: {
                Text(String(localized: "Counted from the start date below — great for every-other-day pet pills."))
            }
        case .weekly:
            Section {
                WeekdayPicker(selection: $schedule.weekdays)
            } header: {
                Text(String(localized: "Which days?"))
            } footer: {
                if schedule.weekdays.isEmpty {
                    Text(String(localized: "Pick at least one day, or this routine would never happen."))
                        .foregroundStyle(.red)
                }
            }
        case .monthly:
            Section {
                MonthDayPicker(selection: $schedule.monthDays)
            } header: {
                Text(String(localized: "Which days of the month?"))
            } footer: {
                if schedule.monthDays.isEmpty {
                    Text(String(localized: "Pick at least one day, or this routine would never happen."))
                        .foregroundStyle(.red)
                } else if schedule.monthDays.contains(where: { $0 >= 29 }) {
                    Text(String(localized: "In shorter months, days 29–31 fall on the last day of the month."))
                }
            }
        default:
            EmptyView()
        }
        Section {
            DatePicker(schedule.kind == .once ? String(localized: "Date") : String(localized: "Starts"),
                       selection: $schedule.startDate, displayedComponents: .date)
            if schedule.kind != .once {
                Toggle(String(localized: "Ends"), isOn: Binding(
                    get: { hasEndDate },
                    set: { on in
                        withAnimation { hasEndDate = on }
                        // Set a real value immediately so the UI never shows a
                        // date that isn't actually stored.
                        schedule.endDate = on
                            ? (schedule.endDate ?? Calendar.current.date(byAdding: .month, value: 1, to: schedule.startDate))
                            : nil
                    }
                ))
                if hasEndDate {
                    DatePicker(String(localized: "End date"),
                               selection: Binding(get: { schedule.endDate ?? schedule.startDate },
                                                  set: { schedule.endDate = $0 }),
                               in: schedule.startDate...,
                               displayedComponents: .date)
                }
            }
        }
    }

    @ViewBuilder private var alertsStep: some View {
        Section {
            ForEach($timeRows) { $row in
                DatePicker(String(localized: "Time"),
                           selection: Binding(
                               get: { dateFromMinutes(row.minutes) },
                               set: { row.minutes = $0.minutesFromMidnight }),
                           displayedComponents: .hourAndMinute)
            }
            .onDelete { timeRows.remove(atOffsets: $0) }
            Button {
                let next = ((timeRows.map(\.minutes).max() ?? 8 * 60) + 60) % (24 * 60)
                timeRows.append(TimeRow(minutes: next))
            } label: {
                Label(String(localized: "Add another time"), systemImage: "plus.circle")
            }
        } header: {
            Text(String(localized: "Times of day"))
        } footer: {
            Text(String(localized: "Add several times for things like morning and evening pills. Swipe to delete a time; delete all for an any-time task (its reminder uses the any-time hour from Settings)."))
        }
        Section {
            Picker(String(localized: "Alert"), selection: $alertMode) {
                ForEach(AlertMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } footer: {
            Text(String(localized: "Alarm mode sends a time-sensitive alert (it can break through Focus when Time Sensitive notifications are allowed) and re-alerts every \(settings.nagIntervalMinutes) min, \(settings.nagCount) times, until you mark it done. It follows the ring/silent switch."))
        }
        if notifications.authorizationStatus == .denied && alertMode != .none {
            Section {
                Label {
                    Text(String(localized: "Notifications are turned off for this app, so this routine can't alert you. Allow them in iOS Settings."))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Link(String(localized: "Open iOS Settings"),
                     destination: URL(string: UIApplication.openSettingsURLString)!)
            }
        }
    }

    @ViewBuilder private var checklistStep: some View {
        Section {
            ForEach($itemRows) { $row in
                TextField(String(localized: "Step"), text: $row.title)
            }
            .onDelete { itemRows.remove(atOffsets: $0) }
            .onMove { itemRows.move(fromOffsets: $0, toOffset: $1) }
            HStack {
                TextField(String(localized: "Add a step (e.g. Morning pill)"), text: $newItemText)
                    .onSubmit(addItem)
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel(Text(String(localized: "Add checklist step")))
                .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text(String(localized: "Checklist (optional)"))
        } footer: {
            Text(String(localized: "Break the routine into steps you tick off one by one — e.g. each pill in the morning batch, or homework subjects. Leave empty for a single checkbox."))
        }
    }

    private var footer: some View {
        HStack {
            if step != .what {
                Button(String(localized: "Back")) {
                    withAnimation { step = Step(rawValue: step.rawValue - 1) ?? .what }
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            if step != .checklist {
                Button(String(localized: "Next")) {
                    withAnimation { step = Step(rawValue: step.rawValue + 1) ?? .checklist }
                }
                .buttonStyle(.borderedProminent)
                .disabled(step == .what && title.trimmingCharacters(in: .whitespaces).isEmpty
                          || step == .when && !scheduleIsValid)
            } else {
                Button(isEditing ? String(localized: "Save Changes") : String(localized: "Create Routine"), action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding()
        .background(.bar)
    }

    // MARK: Draft load/save

    private func loadDraft() {
        guard !loaded else { return }
        loaded = true
        if let routine {
            title = routine.title
            notes = routine.notes
            symbol = routine.symbol
            colorName = routine.colorName
            contextID = routine.contextID
            schedule = routine.schedule
            schedule.interval = min(max(schedule.interval, 2), 90)
            timeRows = routine.timesMinutes.map { TimeRow(minutes: $0) }
            alertMode = routine.alertMode
            // Keep real item IDs so editing preserves checklist identity (and
            // with it, today's partially-completed progress).
            itemRows = routine.sortedItems.map { ItemRow(id: $0.id, title: $0.title, isExisting: true) }
            hasEndDate = routine.schedule.endDate != nil
        } else if let draft {
            title = draft.title
            notes = draft.notes
            symbol = draft.symbol
            colorName = draft.colorName
            contextID = draft.contextID
            schedule = draft.schedule
            schedule.interval = min(max(schedule.interval, 2), 90)
            timeRows = draft.times.map { TimeRow(minutes: $0) }
            alertMode = draft.alertMode
            itemRows = draft.checklist.map { ItemRow(id: UUID(), title: $0, isExisting: false) }
            hasEndDate = draft.schedule.endDate != nil
        }
    }

    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        itemRows.append(ItemRow(id: UUID(), title: trimmed, isExisting: false))
        newItemText = ""
    }

    private func save() {
        addItem() // pick up any un-submitted text
        var finalSchedule = schedule
        if !hasEndDate { finalSchedule.endDate = nil }

        let target: Routine
        if let routine {
            target = routine
        } else {
            target = Routine(title: title)
            modelContext.insert(target)
        }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.notes = notes.trimmingCharacters(in: .whitespaces)
        target.symbol = symbol
        target.colorName = colorName
        target.contextID = contextID
        target.schedule = finalSchedule
        target.timesMinutes = timeRows.map(\.minutes).sorted()
        target.alertMode = alertMode

        // Diff checklist items by identity instead of recreating them, so
        // CompletionRecord.completedItemIDs stay valid across edits.
        let keptRows = itemRows.enumerated().filter { !$0.element.title.trimmingCharacters(in: .whitespaces).isEmpty }
        let keptIDs = Set(keptRows.map { $0.element.id })
        for item in target.items where !keptIDs.contains(item.id) {
            modelContext.delete(item)
        }
        let existingByID = Dictionary(uniqueKeysWithValues: target.items.map { ($0.id, $0) })
        for (order, row) in keptRows {
            if let existing = existingByID[row.id] {
                existing.title = row.title
                existing.order = order
            } else {
                let item = ChecklistItem(id: row.id, title: row.title, order: order)
                item.routine = target
                modelContext.insert(item)
            }
        }

        do {
            try modelContext.save()
        } catch {
            // Never dismiss pretending it worked: surface and keep editing.
            saveFailed = true
            return
        }
        NotificationManager.shared.syncAll()
        if notifications.authorizationStatus == .notDetermined && alertMode != .none {
            NotificationManager.shared.requestAuthorization()
        }
        dismiss()
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        return Calendar.current.date(from: comps) ?? .now
    }
}
