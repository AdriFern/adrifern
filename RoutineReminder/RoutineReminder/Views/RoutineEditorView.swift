import SwiftUI
import SwiftData

/// Multi-step wizard for creating or editing a routine:
/// 1. What — title, icon, who it's for
/// 2. When — recurrence pattern and start date
/// 3. Alerts — times of day and notification/alarm mode
/// 4. Checklist — optional sub-steps to tick off
struct RoutineEditorView: View {
    let routine: Routine?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contexts: [ContextTag]

    private enum Step: Int, CaseIterable {
        case what, when, alerts, checklist

        var title: String {
            switch self {
            case .what: return "What"
            case .when: return "When"
            case .alerts: return "Alerts"
            case .checklist: return "Checklist"
            }
        }
    }

    @State private var step: Step = .what

    // Draft state
    @State private var title = ""
    @State private var notes = ""
    @State private var symbol = "pills"
    @State private var colorName = "blue"
    @State private var contextID: UUID?
    @State private var schedule = Schedule()
    @State private var times: [Int] = [9 * 60]
    @State private var alertMode: AlertMode = .notification
    @State private var checklistTitles: [String] = []
    @State private var newItemText = ""
    @State private var hasEndDate = false
    @State private var loaded = false

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
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: loadDraft)
        }
    }

    // MARK: Steps UI

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                VStack(spacing: 4) {
                    Text(s.title)
                        .font(.caption2.weight(s == step ? .bold : .regular))
                        .foregroundStyle(s == step ? Color.accentColor : .secondary)
                    Capsule()
                        .fill(s.rawValue <= step.rawValue ? Color.accentColor : Color(.systemGray4))
                        .frame(height: 4)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation { step = s } }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
    }

    @ViewBuilder private var whatStep: some View {
        Section("What do you need to remember?") {
            TextField("Title (e.g. Take my pills)", text: $title)
            TextField("Notes (optional)", text: $notes, axis: .vertical)
        }
        Section("Look") {
            SymbolColorPicker(symbol: $symbol, colorName: $colorName, symbols: SymbolChoices.routine)
        }
        Section {
            Picker("Who is this for?", selection: $contextID) {
                Text("Me / always").tag(UUID?.none)
                ForEach(contexts) { context in
                    Label(context.name, systemImage: context.symbol).tag(UUID?.some(context.id))
                }
            }
        } footer: {
            if contexts.isEmpty {
                Text("Add people or pets with week patterns in the People & Pets tab — then routines linked to them only remind you on the days they're with you.")
            } else {
                Text("Linked routines only remind you on days that person or pet is with you.")
            }
        }
    }

    @ViewBuilder private var whenStep: some View {
        Section("How often?") {
            Picker("Repeat", selection: $schedule.kind) {
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
                Stepper(value: $schedule.interval, in: 2...30) {
                    Text(schedule.interval == 2 ? "Every other day" : "Every \(schedule.interval) days")
                }
            } footer: {
                Text("Counted from the start date below — great for every-other-day pet pills.")
            }
        case .weekly:
            Section("Which days?") {
                WeekdayPicker(selection: $schedule.weekdays)
            }
        case .monthly:
            Section("Which days of the month?") {
                MonthDayPicker(selection: $schedule.monthDays)
            }
        default:
            EmptyView()
        }
        Section {
            DatePicker(schedule.kind == .once ? "Date" : "Starts", selection: $schedule.startDate, displayedComponents: .date)
            if schedule.kind != .once {
                Toggle("Ends", isOn: $hasEndDate.animation())
                if hasEndDate {
                    DatePicker("End date",
                               selection: Binding(get: { schedule.endDate ?? schedule.startDate },
                                                  set: { schedule.endDate = $0 }),
                               displayedComponents: .date)
                }
            }
        }
    }

    @ViewBuilder private var alertsStep: some View {
        Section {
            ForEach(times.indices, id: \.self) { index in
                DatePicker("Time \(times.count > 1 ? "\(index + 1)" : "")",
                           selection: Binding(
                               get: { dateFromMinutes(times[index]) },
                               set: { times[index] = $0.minutesFromMidnight }),
                           displayedComponents: .hourAndMinute)
            }
            .onDelete { times.remove(atOffsets: $0) }
            Button {
                times.append(((times.max() ?? 8 * 60) + 60) % (24 * 60))
            } label: {
                Label("Add another time", systemImage: "plus.circle")
            }
        } header: {
            Text("Times of day")
        } footer: {
            Text("Add several times for things like morning and evening pills. Swipe to delete a time; delete all for an any-time task.")
        }
        Section {
            Picker("Alert", selection: $alertMode) {
                ForEach(AlertMode.allCases) { mode in
                    Label(mode.label, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } footer: {
            Text("Alarm mode sends a time-sensitive alert that breaks through Focus modes and re-notifies every \(NotificationManager.nagInterval) minutes (\(NotificationManager.nagCount) times) until you mark it done.")
        }
    }

    @ViewBuilder private var checklistStep: some View {
        Section {
            ForEach(checklistTitles.indices, id: \.self) { index in
                TextField("Step \(index + 1)", text: $checklistTitles[index])
            }
            .onDelete { checklistTitles.remove(atOffsets: $0) }
            .onMove { checklistTitles.move(fromOffsets: $0, toOffset: $1) }
            HStack {
                TextField("Add a step (e.g. Blood pressure pill)", text: $newItemText)
                    .onSubmit(addItem)
                Button(action: addItem) {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(newItemText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Checklist (optional)")
        } footer: {
            Text("Break the routine into steps you tick off one by one — e.g. each pill in the morning batch, or homework subjects. Leave empty for a single checkbox.")
        }
    }

    private var footer: some View {
        HStack {
            if step != .what {
                Button("Back") {
                    withAnimation { step = Step(rawValue: step.rawValue - 1) ?? .what }
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            if step != .checklist {
                Button("Next") {
                    withAnimation { step = Step(rawValue: step.rawValue + 1) ?? .checklist }
                }
                .buttonStyle(.borderedProminent)
                .disabled(step == .what && title.trimmingCharacters(in: .whitespaces).isEmpty)
            } else {
                Button(routine == nil ? "Create Routine" : "Save Changes", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .background(.bar)
    }

    // MARK: Draft load/save

    private func loadDraft() {
        guard !loaded else { return }
        loaded = true
        guard let routine else { return }
        title = routine.title
        notes = routine.notes
        symbol = routine.symbol
        colorName = routine.colorName
        contextID = routine.contextID
        schedule = routine.schedule
        times = routine.timesMinutes
        alertMode = routine.alertMode
        checklistTitles = routine.sortedItems.map { $0.title }
        hasEndDate = routine.schedule.endDate != nil
    }

    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        checklistTitles.append(trimmed)
        newItemText = ""
    }

    private func save() {
        addItem() // pick up any un-submitted text
        var finalSchedule = schedule
        if !hasEndDate { finalSchedule.endDate = nil }

        let target: Routine
        if let routine {
            target = routine
            for item in routine.items {
                modelContext.delete(item)
            }
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
        target.timesMinutes = times.sorted()
        target.alertMode = alertMode
        target.items = checklistTitles.enumerated()
            .filter { !$0.element.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { ChecklistItem(title: $0.element, order: $0.offset) }

        try? modelContext.save()
        NotificationManager.shared.syncAll()
        if NotificationManager.shared.authorizationStatus == .notDetermined && alertMode != .none {
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
