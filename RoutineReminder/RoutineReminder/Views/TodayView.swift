import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject private var notifications = NotificationManager.shared

    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var userNavigated = false
    @State private var showingQuickAdd = false
    @State private var showingWizard = false
    @State private var showingPetCorner = false

    var body: some View {
        NavigationStack {
            DayChecklistView(day: selectedDay)
                .id(selectedDay) // re-create so the day-scoped @Query updates
                .navigationTitle(navigationTitle)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button { move(-1) } label: { Image(systemName: "chevron.left") }
                            .accessibilityLabel(Text(String(localized: "Previous day")))
                        Button(String(localized: "Today")) {
                            selectedDay = Calendar.current.startOfDay(for: .now)
                            userNavigated = false
                        }
                        .disabled(Calendar.current.isDateInToday(selectedDay))
                        Button { move(1) } label: { Image(systemName: "chevron.right") }
                            .accessibilityLabel(Text(String(localized: "Next day")))
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showingPetCorner = true
                        } label: {
                            Text(settings.companion.emoji)
                                .font(.title3)
                        }
                        .accessibilityLabel(Text(String(localized: "Visit \(settings.companion.name)")))
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
                }
                .sheet(isPresented: $showingQuickAdd) { QuickAddView() }
                .sheet(isPresented: $showingWizard) { RoutineEditorView(routine: nil) }
                .sheet(isPresented: $showingPetCorner) { PetCornerView() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Never greet the user with yesterday's checklist: snap forward on
            // wake unless they deliberately navigated to another day.
            if phase == .active && !userNavigated {
                selectedDay = Calendar.current.startOfDay(for: .now)
            }
        }
        .onChange(of: notifications.openRequest) { _, request in
            if let request {
                selectedDay = request.day
                userNavigated = false
                notifications.openRequest = nil
            }
        }
    }

    private var navigationTitle: String {
        if Calendar.current.isDateInToday(selectedDay) { return String(localized: "Today") }
        if Calendar.current.isDateInTomorrow(selectedDay) { return String(localized: "Tomorrow") }
        if Calendar.current.isDateInYesterday(selectedDay) { return String(localized: "Yesterday") }
        return selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func move(_ days: Int) {
        if let newDay = Calendar.current.date(byAdding: .day, value: days, to: selectedDay) {
            selectedDay = newDay
            userNavigated = !Calendar.current.isDateInToday(newDay)
        }
    }
}

// MARK: - Day checklist (shared by Today and the calendar's day detail)

struct DayChecklistView: View {
    let day: Date

    @Environment(\.modelContext) private var modelContext
    @Query private var routines: [Routine]
    @Query private var contexts: [ContextTag]
    @Query private var completions: [CompletionRecord]

    init(day: Date) {
        self.day = day
        let key = Scheduler.dayKey(for: day)
        // Day-scoped query: never loads the full completion history.
        _completions = Query(filter: #Predicate<CompletionRecord> { $0.dayKey == key })
    }

    var body: some View {
        let occurrences = Scheduler.occurrences(for: routines, contexts: contexts, on: day)
        let routineMap = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        let activeContexts = contexts.filter { Scheduler.isContextActive($0.pattern, on: day) && $0.pattern.kind != .always }
        let doneCount = occurrences.filter { record(for: $0)?.isDone == true }.count

        List {
            if !activeContexts.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(activeContexts) { context in
                                ContextChip(context: context)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 0, trailing: 20))
                } header: {
                    Text(Calendar.current.isDateInToday(day)
                         ? String(localized: "With you today")
                         : String(localized: "With you this day"))
                }
            }

            if occurrences.isEmpty {
                Section {
                    EmptyStateView(symbol: "checkmark.circle",
                                   title: String(localized: "Nothing scheduled"),
                                   message: String(localized: "A free day! Add a routine with the + button — or just type what you need in Quick Add."))
                        .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(occurrences) { occurrence in
                        if let routine = routineMap[occurrence.routineID] {
                            OccurrenceRow(occurrence: occurrence,
                                          routine: routine,
                                          record: record(for: occurrence))
                        }
                    }
                } header: {
                    Text(String(localized: "\(doneCount) of \(occurrences.count) done"))
                } footer: {
                    if doneCount == occurrences.count && !occurrences.isEmpty {
                        Label {
                            Text(String(localized: "All done — \(AppSettings.shared.companion.name) is thrilled! 🎉"))
                        } icon: {
                            Text(AppSettings.shared.companion.emoji)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: doneCount) { old, new in new > old }
    }

    private func record(for occurrence: Occurrence) -> CompletionRecord? {
        completions.first {
            $0.routineID == occurrence.routineID && $0.slotMinutes == occurrence.slotMinutes
        }
    }
}

// MARK: - Row

struct OccurrenceRow: View {
    let occurrence: Occurrence
    let routine: Routine
    let record: CompletionRecord?

    @Environment(\.modelContext) private var modelContext
    @State private var expanded = false
    @State private var justCompleted = false

    private var isDone: Bool { record?.isDone == true }

    /// Only IDs that still exist on the routine count — stale IDs from old
    /// edits can never inflate progress.
    private var completedItemIDs: Set<UUID> {
        let current = Set(routine.items.map { $0.id })
        return Set(record?.completedItemIDs ?? []).intersection(current)
    }

    private var isOverdue: Bool {
        !isDone && Calendar.current.isDateInToday(occurrence.day) && occurrence.fireDate < .now
            && occurrence.slotMinutes >= 0 && routine.alertMode != .none
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button(action: toggleDone) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isDone ? Palette.color(routine.colorName) : .secondary)
                        .symbolEffect(.bounce, value: justCompleted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(isDone
                    ? String(localized: "Mark \(routine.title) as not done")
                    : String(localized: "Mark \(routine.title) done")))

                Image(systemName: routine.symbol)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Palette.color(routine.colorName).gradient, in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.title)
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? .secondary : .primary)
                    HStack(spacing: 6) {
                        if isOverdue {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(occurrence.slotMinutes.timeString)
                                .foregroundStyle(.red)
                        } else if occurrence.slotMinutes >= 0 {
                            Text(occurrence.slotMinutes.timeString)
                        } else {
                            Text(String(localized: "Any time"))
                        }
                        if routine.alertMode != .none {
                            Image(systemName: routine.alertMode.symbol)
                        }
                        if !routine.items.isEmpty {
                            Text("\(completedItemIDs.count)/\(routine.items.count)")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if !routine.items.isEmpty {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if routine.items.isEmpty {
                    toggleDone()
                } else {
                    withAnimation { expanded.toggle() }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(isDone ? String(localized: "Done") : String(localized: "Not done")))

            if expanded && !routine.items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(routine.sortedItems) { item in
                        let itemDone = completedItemIDs.contains(item.id)
                        Button {
                            toggleItem(item)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: itemDone ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(itemDone ? Palette.color(routine.colorName) : .secondary)
                                Text(item.title)
                                    .font(.subheadline)
                                    .strikethrough(itemDone)
                                    .foregroundStyle(itemDone ? .secondary : .primary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 46)
                .padding(.top, 10)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Completion

    private func fetchOrCreateRecord() -> CompletionRecord? {
        CompletionStore.record(for: occurrence.routineID,
                               dayKey: Scheduler.dayKey(for: occurrence.day),
                               slotMinutes: occurrence.slotMinutes,
                               in: modelContext, createIfMissing: true)
    }

    private func toggleDone() {
        guard let record = fetchOrCreateRecord() else { return }
        record.isDone.toggle()
        record.completedAt = record.isDone ? .now : nil
        if record.isDone {
            record.completedItemIDs = routine.items.map { $0.id }
            justCompleted.toggle()
            AppSettings.shared.awardCompletion()
            NotificationManager.shared.cancel(occurrenceID: occurrence.id)
        } else {
            record.completedItemIDs = []
            AppSettings.shared.revokeCompletion()
            NotificationManager.shared.syncAll()
        }
        try? modelContext.save()
    }

    private func toggleItem(_ item: ChecklistItem) {
        guard let record = fetchOrCreateRecord() else { return }
        var ids = completedItemIDs
        if ids.contains(item.id) { ids.remove(item.id) } else { ids.insert(item.id) }
        record.completedItemIDs = Array(ids)
        let wasDone = record.isDone
        let allDone = !routine.items.isEmpty && ids.count >= routine.items.count
        record.isDone = allDone
        record.completedAt = allDone ? .now : nil
        if allDone && !wasDone {
            justCompleted.toggle()
            AppSettings.shared.awardCompletion()
            NotificationManager.shared.cancel(occurrenceID: occurrence.id)
        } else if !allDone && wasDone {
            AppSettings.shared.revokeCompletion()
            NotificationManager.shared.syncAll()
        }
        try? modelContext.save()
    }
}
