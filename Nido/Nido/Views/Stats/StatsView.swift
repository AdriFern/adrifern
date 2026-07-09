import SwiftUI

/// Custody statistics: monthly and yearly split between the two parents.
struct StatsView: View {
    @Environment(FamilyStore.self) private var store
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var aiSummary: String?
    @State private var isSummarizing = false

    private var yearRange: ClosedRange<Int> {
        let current = Calendar.current.component(.year, from: Date())
        return (current - 3)...(current + 3)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if store.members.count > 1 {
                        MemberSwitcher()
                            .padding(.horizontal, -20)
                    }

                    yearPicker

                    if let family = store.selectedMember.flatMap({ store.context($0.id)?.family }) {
                        yearSummaryCard(family: family)
                        monthSummaryCard(family: family)
                        equityCard(family: family)
                        monthlyBreakdownCard(family: family)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(Text("Stats"))
            .onChange(of: store.selectedMember?.id) { _, _ in
                aiSummary = nil
            }
        }
    }

    private var memberAssignments: [String: ParentRole] {
        guard let member = store.selectedMember else { return [:] }
        return store.assignments[member.id] ?? [:]
    }

    // MARK: - Year picker

    private var yearPicker: some View {
        HStack {
            Button {
                withAnimation { year -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(Theme.cardBackground, in: Circle())
            }
            .disabled(year <= yearRange.lowerBound)
            .accessibilityLabel(Text("Previous year"))
            Spacer()
            Text(String(year))
                .font(.title3.bold())
                .contentTransition(.numericText())
            Spacer()
            Button {
                withAnimation { year += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(Theme.cardBackground, in: Circle())
            }
            .disabled(year >= yearRange.upperBound)
            .accessibilityLabel(Text("Next year"))
        }
    }

    // MARK: - Counting

    private func counts(forPrefix prefix: String) -> (a: Int, b: Int) {
        var a = 0, b = 0
        for (key, owner) in memberAssignments where key.hasPrefix(prefix) {
            if owner == .parentA { a += 1 } else { b += 1 }
        }
        return (a, b)
    }

    private var yearPrefix: String { String(format: "%04d-", year) }

    // MARK: - Year summary

    private func yearSummaryCard(family: Family) -> some View {
        let totals = counts(forPrefix: yearPrefix)
        let total = totals.a + totals.b
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                if let member = store.selectedMember, store.members.count > 1 {
                    Image(systemName: member.symbolName)
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                    Text("\(member.name) — days with each parent in \(String(year))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Days with each parent in \(String(year))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 16) {
                statTile(
                    name: family.name(of: .parentA),
                    colorHex: family.colorA,
                    count: totals.a,
                    total: total
                )
                statTile(
                    name: family.name(of: .parentB),
                    colorHex: family.colorB,
                    count: totals.b,
                    total: total
                )
            }

            SplitBar(
                a: totals.a,
                b: totals.b,
                colorA: Color(hex: family.colorA),
                colorB: Color(hex: family.colorB)
            )
            .frame(height: 14)

            if total == 0 {
                Text("Assign days on the calendar to see statistics.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }

    private func statTile(name: String, colorHex: String, count: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ParentDot(colorHex: colorHex)
                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text("\(count)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(verbatim: total > 0 ? "\(Int((Double(count) / Double(total) * 100).rounded()))%" : "—")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - This month

    private func monthFacts(family: Family) -> String {
        let now = Date()
        let prefix = String(Day.key(for: now).prefix(7)) + "-"
        let totals = counts(forPrefix: prefix)
        let monthName = now.formatted(.dateTime.month(.wide))
        let memberName = store.selectedMember?.name ?? ""
        var approved = 0, declined = 0, pending = 0
        if let member = store.selectedMember {
            for request in store.requests
            where request.memberID == member.id
                && Day.calendar.isDate(request.createdAt, equalTo: now, toGranularity: .month) {
                switch request.status {
                case .approved: approved += 1
                case .declined: declined += 1
                case .pending: pending += 1
                case .cancelled: break
                }
            }
        }
        var parts = [String(localized: "\(memberName) in \(monthName) — days with \(family.name(of: .parentA)): \(totals.a) · \(family.name(of: .parentB)): \(totals.b).")]
        if approved + declined + pending > 0 {
            parts.append(String(localized: "Requests this month — approved: \(approved), declined: \(declined), pending: \(pending)."))
        }
        return parts.joined(separator: " ")
    }

    private func monthSummaryCard(family: Family) -> some View {
        let facts = monthFacts(family: family)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This month")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if NidoIntelligence.isAvailable {
                    Button {
                        summarize(facts)
                    } label: {
                        if isSummarizing {
                            ProgressView()
                        } else {
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .disabled(isSummarizing)
                    .accessibilityLabel(Text("Retell with Apple Intelligence"))
                }
            }

            Text(aiSummary ?? facts)
                .font(.subheadline)

            if aiSummary != nil {
                Text("Written on this device by Apple Intelligence from the numbers above — nothing leaves your iPhone.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }

    private func summarize(_ facts: String) {
        Task {
            isSummarizing = true
            if let summary = await NidoIntelligence.monthlySummary(facts: facts) {
                aiSummary = summary
            }
            isSummarizing = false
        }
    }

    // MARK: - Fairness check

    private func equityCard(family: Family) -> some View {
        let insights = EquityAnalysis.insights(assignments: memberAssignments, family: family)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Fairness check")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: insight.symbolName)
                        .font(.subheadline)
                        .foregroundStyle(insight.kind == .balanced ? Color.green : Color.accentColor)
                        .frame(width: 22)
                    Text(insight.text)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Text("Computed on this device from the assigned days — information for both of you, not a scorecard.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }

    // MARK: - Monthly breakdown

    private func monthlyBreakdownCard(family: Family) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Month by month")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(1...12, id: \.self) { monthNumber in
                let prefix = String(format: "%04d-%02d", year, monthNumber)
                let totals = counts(forPrefix: prefix)
                HStack(spacing: 12) {
                    Text(Day.calendar.shortStandaloneMonthSymbols[monthNumber - 1].capitalized)
                        .font(.subheadline)
                        .frame(minWidth: 44, alignment: .leading)
                        .lineLimit(1)
                    SplitBar(
                        a: totals.a,
                        b: totals.b,
                        colorA: Color(hex: family.colorA),
                        colorB: Color(hex: family.colorB)
                    )
                    .frame(height: 10)
                    Text("\(totals.a)·\(totals.b)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .padding(20)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }
}

// MARK: - Split bar

/// A proportional two-color bar showing the custody split.
struct SplitBar: View {
    var a: Int
    var b: Int
    var colorA: Color
    var colorB: Color

    var body: some View {
        GeometryReader { proxy in
            let total = max(a + b, 1)
            let widthA = proxy.size.width * Double(a) / Double(total)
            HStack(spacing: a > 0 && b > 0 ? 2 : 0) {
                if a > 0 {
                    Capsule().fill(colorA)
                        .frame(width: max(widthA - 1, 4))
                }
                if b > 0 {
                    Capsule().fill(colorB)
                }
                if a == 0 && b == 0 {
                    Capsule().fill(Color(.tertiarySystemFill))
                }
            }
        }
    }
}
