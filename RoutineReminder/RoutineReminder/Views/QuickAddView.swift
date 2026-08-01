import SwiftUI
import SwiftData

/// Describe a reminder in plain English or Spanish and get a parsed preview.
/// Parsing is rule-based and runs entirely on-device — no AI service involved.
/// If the parse isn't quite right, "Refine" hands the draft to the full editor.
struct QuickAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var contexts: [ContextTag]

    @State private var input = ""
    @State private var alertMode: AlertMode = .notification
    @State private var refining = false
    @FocusState private var focused: Bool

    private var examples: [String] {
        if Locale.current.language.languageCode?.identifier == "es" {
            return [
                "Tomar mis pastillas cada día a las 8",
                "Skincare un día sí y un día no empezando esta noche",
                "Deberes a las 5 de la tarde cuando tengo a Emma",
                "Pastilla de Rocky cada 2 días a las 7 de la tarde",
                "Pagar alquiler cada mes el 1",
            ]
        }
        return [
            "Take my pills every day at 8am",
            "Apply skincare every other day starting tonight",
            "Homework at 5pm when I have Emma",
            "Give Rocky his pill every 2 days at 7pm",
            "Pay rent monthly on the 1st",
        ]
    }

    private var parsed: ParsedReminder? {
        QuickAddParser.parse(input, contexts: contexts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "e.g. Remind me to take my pill every morning at 8"),
                              text: $input, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focused)
                } header: {
                    Text(String(localized: "Describe your reminder"))
                } footer: {
                    Text(String(localized: "Understood entirely on your phone — nothing is sent anywhere."))
                }

                if input.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section(String(localized: "Try one of these")) {
                        ForEach(examples, id: \.self) { example in
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
                    Section(String(localized: "Preview")) {
                        LabeledContent(String(localized: "Title"), value: parsed.title)
                        LabeledContent(String(localized: "Repeats"), value: parsed.schedule.recurrenceText)
                        LabeledContent(String(localized: "Time"),
                                       value: parsed.timeMinutes?.timeString ?? String(localized: "Any time"))
                        LabeledContent(String(localized: "Starts"),
                                       value: parsed.schedule.startDate.formatted(date: .abbreviated, time: .omitted))
                        if let context = parsed.matchedContext {
                            LabeledContent(String(localized: "Only when with you")) {
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
                        Picker(String(localized: "Alert"), selection: $alertMode) {
                            ForEach(AlertMode.allCases) { mode in
                                Label(mode.label, systemImage: mode.symbol).tag(mode)
                            }
                        }
                    } footer: {
                        Text(String(localized: "Not quite right? Refine opens the full editor with everything pre-filled."))
                    }
                    Section {
                        Button {
                            refining = true
                        } label: {
                            Label(String(localized: "Refine in editor…"), systemImage: "slider.horizontal.3")
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "Quick Add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save"), action: save)
                        .disabled(parsed == nil)
                }
            }
            .onAppear { focused = true }
            .sheet(isPresented: $refining, onDismiss: { dismiss() }) {
                if let parsed {
                    RoutineEditorView(routine: nil, draft: RoutineDraft(
                        title: parsed.title,
                        contextID: parsed.matchedContext?.id,
                        schedule: parsed.schedule,
                        times: parsed.timeMinutes.map { [$0] } ?? [],
                        alertMode: alertMode
                    ))
                }
            }
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
