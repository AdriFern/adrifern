import SwiftUI

/// Wizard for applying a repeating custody pattern over a date range.
struct PatternSheet: View {
    @Environment(FamilyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var template: PatternTemplate = .alternatingWeeks
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var firstParent: ParentRole = .parentA
    @State private var weekdaysForFirst: Set<Int> = [2, 3, 4, 5, 6]
    @State private var isApplying = false
    @State private var outcomeSummary: OutcomeSummary?

    /// Keep the range inside what the calendar can display.
    private var latestAllowedDate: Date {
        Day.calendar.date(byAdding: .month, value: 36, to: Date()) ?? Date()
    }

    private var proposal: [String: ParentRole] {
        guard startDate <= endDate else { return [:] }
        return PatternGenerator.generate(
            template: template,
            start: startDate,
            end: endDate,
            firstParent: firstParent,
            weekdaysForFirst: weekdaysForFirst
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    templatePicker

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Dates")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        DatePicker("From", selection: $startDate, in: ...latestAllowedDate, displayedComponents: .date)
                        DatePicker("Until", selection: $endDate, in: startDate...latestAllowedDate, displayedComponents: .date)
                    }
                    .padding(16)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))

                    firstParentPicker

                    if template == .weekly {
                        weekdayPicker
                    }

                    previewStrip

                    footerNote

                    Button {
                        applyPattern()
                    } label: {
                        if isApplying {
                            ProgressView().tint(.white)
                        } else {
                            Text("Apply schedule")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isApplying || proposal.isEmpty)
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(Text("Repeating schedule"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { firstParent = store.myRole }
            .alert(item: $outcomeSummary) { summary in
                Alert(
                    title: Text(summary.title),
                    message: Text(summary.text),
                    dismissButton: .default(Text("OK")) { dismiss() }
                )
            }
        }
    }

    // MARK: - Template picker

    private var templatePicker: some View {
        VStack(spacing: 10) {
            ForEach(PatternTemplate.allCases) { option in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { template = option }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: option.symbolName)
                            .font(.title3)
                            .foregroundStyle(template == option ? Color.accentColor : Color.secondary)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: template == option ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(template == option ? Color.accentColor : Color(.systemGray4))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                            .fill(Theme.cardBackground)
                            .overlay {
                                if template == option {
                                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                                }
                            }
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Parent picker

    private var firstParentLabel: String {
        switch template {
        case .alternatingWeeks, .twoTwoThree: String(localized: "First turn")
        case .everyOtherWeekend: String(localized: "Weekdays stay with")
        case .weekly: String(localized: "Selected weekdays go to")
        }
    }

    private var firstParentPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(firstParentLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if let family = store.family {
                Picker(firstParentLabel, selection: $firstParent) {
                    Text(family.name(of: .parentA)).tag(ParentRole.parentA)
                    Text(family.name(of: .parentB)).tag(ParentRole.parentB)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Weekday picker (weekly template)

    private var weekdayPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let family = store.family {
                Text("Days of the week for \(family.name(of: firstParent))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                let symbols = Day.calendar.veryShortStandaloneWeekdaySymbols
                let order = orderedWeekdays
                ForEach(order, id: \.self) { weekday in
                    let selected = weekdaysForFirst.contains(weekday)
                    Button {
                        if selected {
                            weekdaysForFirst.remove(weekday)
                        } else {
                            weekdaysForFirst.insert(weekday)
                        }
                    } label: {
                        Text(symbols[weekday - 1])
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(
                                selected ? Color.accentColor : Theme.cardBackground,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .foregroundStyle(selected ? .white : .primary)
                    }
                }
            }
        }
    }

    private var orderedWeekdays: [Int] {
        let first = Day.calendar.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    // MARK: - Preview

    private var previewStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview (first two weeks)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if let family = store.family {
                let keys = Day.keys(
                    from: startDate,
                    to: Day.calendar.date(byAdding: .day, value: 13, to: startDate) ?? startDate
                )
                HStack(spacing: 4) {
                    ForEach(keys, id: \.self) { key in
                        let owner = proposal[key]
                        VStack(spacing: 3) {
                            Text(dayNumberLabel(for: key))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                            Circle()
                                .fill(owner.map { Color(hex: family.colorHex(of: $0)) } ?? Color(.systemGray4))
                                .frame(width: 12, height: 12)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(14)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
        }
    }

    private func dayNumberLabel(for key: String) -> String {
        guard let date = Day.date(from: key) else { return "" }
        return "\(Day.calendar.component(.day, from: date))"
    }

    // MARK: - Footer + apply

    private var footerNote: some View {
        Label {
            Text("If any day would change hands, the whole schedule is sent to \(store.otherName) as one proposal — nothing is applied until they approve it. Otherwise it's filled in right away.")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private struct OutcomeSummary: Identifiable {
        let id = UUID()
        let title: String
        let text: String
    }

    private func applyPattern() {
        Task {
            isApplying = true
            let outcome = await store.applyPattern(proposal)
            isApplying = false
            guard let outcome else { return }

            var parts: [String] = []
            let title: String
            if outcome.sentForApproval > 0 {
                title = String(localized: "Proposal sent")
                parts.append(String(localized: "The schedule was sent to \(store.otherName) as one proposal covering \(outcome.sentForApproval) days. It will apply once they approve it."))
            } else if outcome.appliedDirectly > 0 {
                title = String(localized: "Schedule applied")
                parts.append(String(localized: "\(outcome.appliedDirectly) days were filled in."))
            } else {
                title = String(localized: "Nothing to change")
                parts.append(String(localized: "Everything already matched this schedule — nothing to change."))
            }
            if outcome.skippedPending > 0 {
                parts.append(String(localized: "\(outcome.skippedPending) days were skipped because they're part of a pending request."))
            }
            outcomeSummary = OutcomeSummary(title: title, text: parts.joined(separator: " "))
        }
    }
}
