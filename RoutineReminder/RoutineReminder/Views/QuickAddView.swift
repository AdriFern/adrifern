import SwiftUI
import SwiftData

/// Describe a reminder in plain English and get a parsed, editable preview.
/// Parsing is rule-based and runs entirely on-device — no AI service involved.
struct QuickAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contexts: [ContextTag]

    @State private var input = ""
    @State private var alertMode: AlertMode = .notification
    @FocusState private var focused: Bool

    private static let examples = [
        "Take my pills every day at 8am",
        "Apply skincare every other day starting tonight",
        "Homework at 5pm when I have Emma",
        "Give Rocky his pill every 2 days at 7pm",
        "Team report every friday at 9am",
        "Pay rent monthly on the 1st",
    ]

    private var parsed: ParsedReminder? {
        QuickAddParser.parse(input, contexts: contexts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Remind me to take my pill every morning at 8", text: $input, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focused)
                } header: {
                    Text("Describe your reminder")
                } footer: {
                    Text("Understood entirely on your phone — nothing is sent anywhere.")
                }

                if input.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section("Try one of these") {
                        ForEach(Self.examples, id: \.self) { example in
                            Button {
                                input = example
                            } label: {
                                Text(example)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                if let parsed {
                    Section("Preview — tap Save if it looks right") {
                        LabeledContent("Title", value: parsed.title)
                        LabeledContent("Repeats", value: parsed.schedule.recurrenceText)
                        LabeledContent("Time", value: parsed.timeMinutes?.timeString ?? "Any time")
                        LabeledContent("Starts", value: parsed.schedule.startDate.formatted(date: .abbreviated, time: .omitted))
                        if let context = parsed.matchedContext {
                            LabeledContent("Only when with you") {
                                ContextChip(context: context)
                            }
                        }
                        ForEach(parsed.notes, id: \.self) { note in
                            Label(note, systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Picker("Alert", selection: $alertMode) {
                            ForEach(AlertMode.allCases) { mode in
                                Label(mode.label, systemImage: mode.symbol).tag(mode)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(parsed == nil)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func save() {
        guard let parsed else { return }
        let routine = Routine(title: parsed.title,
                              schedule: parsed.schedule,
                              timesMinutes: parsed.timeMinutes.map { [$0] } ?? [],
                              alertMode: alertMode,
                              contextID: parsed.matchedContext?.id)
        modelContext.insert(routine)
        try? modelContext.save()
        NotificationManager.shared.syncAll()
        if NotificationManager.shared.authorizationStatus == .notDetermined && alertMode != .none {
            NotificationManager.shared.requestAuthorization()
        }
        dismiss()
    }
}
