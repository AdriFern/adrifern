import SwiftUI
import SwiftData

struct TodayView: View {
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var showingQuickAdd = false
    @State private var showingWizard = false

    var body: some View {
        NavigationStack {
            DayChecklistView(day: selectedDay)
                .navigationTitle(navigationTitle)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarLeading) {
                        Button { move(-1) } label: { Image(systemName: "chevron.left") }
                        Button("Today") { selectedDay = Calendar.current.startOfDay(for: .now) }
                            .disabled(Calendar.current.isDateInToday(selectedDay))
                        Button { move(1) } label: { Image(systemName: "chevron.right") }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { showingQuickAdd = true } label: {
                            Image(systemName: "text.bubble")
                        }
                        Button { showingWizard = true } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingQuickAdd) { QuickAddView() }
                .sheet(isPresented: $showingWizard) { RoutineEditorView(routine: nil) }
        }
    }

    private var navigationTitle: String {
        if Calendar.current.isDateInToday(selectedDay) { return "Today" }
        if Calendar.current.isDateInTomorrow(selectedDay) { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(selectedDay) { return "Yesterday" }
        return selectedDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func move(_ days: Int) {
        if let newDay = Calendar.current.date(byAdding: .day, value: days, to: selectedDay) {
            selectedDay = newDay
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

    var body: some View {
        let occurrences = Scheduler.occurrences(for: routines, contexts: contexts, on: day)
        let routineMap = Dictionary(uniqueKeysWithValues: routines.map { ($0.id, $0) })
        let activeContexts = contexts.filter { Scheduler.isContextActive($0.pattern, on: day) && $0.pattern.kind != .always }

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
                    Text("With you \(Calendar.current.isDateInToday(day) ? "today" : "this day")")
                }
            }

            if occurrences.isEmpty {
                EmptyStateView(symbol: "checkmark.circle",
                               title: "Nothing scheduled",
                               message: "Add a routine with + or describe one in Quick Add.")
                    .listRowBackground(Color.clear)
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
                    let done = occurrences.filter { record(for: $0)?.isDone == true }.count
                    Text("\(done) of \(occurrences.count) done")
                }
            }
        }
    }

    private func record(for occurrence: Occurrence) -> CompletionRecord? {
        let key = Scheduler.dayKey(for: occurrence.day)
        return completions.first {
            $0.routineID == occurrence.routineID && $0.dayKey == key && $0.slotMinutes == occurrence.slotMinutes
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

    private var isDone: Bool { record?.isDone == true }
    private var completedItemIDs: Set<UUID> { Set(record?.completedItemIDs ?? []) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button(action: toggleDone) {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isDone ? Palette.color(routine.colorName) : .secondary)
                }
                .buttonStyle(.plain)

                Image(systemName: routine.symbol)
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Palette.color(routine.colorName).gradient, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.title)
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? .secondary : .primary)
                    HStack(spacing: 6) {
                        if occurrence.slotMinutes >= 0 {
                            Text(occurrence.slotMinutes.timeString)
                        } else {
                            Text("Any time")
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

            if expanded && !routine.items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(routine.sortedItems) { item in
                        let itemDone = completedItemIDs.contains(item.id)
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
                        .onTapGesture { toggleItem(item) }
                    }
                }
                .padding(.leading, 46)
                .padding(.top, 10)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Completion

    private func fetchOrCreateRecord() -> CompletionRecord {
        if let record { return record }
        let newRecord = CompletionRecord(routineID: occurrence.routineID,
                                         dayKey: Scheduler.dayKey(for: occurrence.day),
                                         slotMinutes: occurrence.slotMinutes)
        modelContext.insert(newRecord)
        return newRecord
    }

    private func toggleDone() {
        let record = fetchOrCreateRecord()
        record.isDone.toggle()
        record.completedAt = record.isDone ? .now : nil
        if record.isDone {
            record.completedItemIDs = routine.items.map { $0.id }
            NotificationManager.shared.cancel(occurrenceID: occurrence.id)
        } else {
            record.completedItemIDs = []
            NotificationManager.shared.syncAll()
        }
        try? modelContext.save()
    }

    private func toggleItem(_ item: ChecklistItem) {
        let record = fetchOrCreateRecord()
        var ids = Set(record.completedItemIDs)
        if ids.contains(item.id) { ids.remove(item.id) } else { ids.insert(item.id) }
        record.completedItemIDs = Array(ids)
        let allDone = !routine.items.isEmpty && ids.count >= routine.items.count
        record.isDone = allDone
        record.completedAt = allDone ? .now : nil
        if allDone {
            NotificationManager.shared.cancel(occurrenceID: occurrence.id)
        }
        try? modelContext.save()
    }
}
