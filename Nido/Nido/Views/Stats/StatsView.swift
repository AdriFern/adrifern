import SwiftUI

/// Custody statistics: monthly and yearly split between the two parents.
struct StatsView: View {
    @Environment(FamilyStore.self) private var store
    @State private var year = Calendar.current.component(.year, from: Date())

    private var yearRange: ClosedRange<Int> {
        let current = Calendar.current.component(.year, from: Date())
        return (current - 3)...(current + 3)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    yearPicker

                    if let family = store.family {
                        yearSummaryCard(family: family)
                        monthlyBreakdownCard(family: family)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(Text("Stats"))
        }
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
        for (key, owner) in store.assignments where key.hasPrefix(prefix) {
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
            Text("Days with each parent in \(String(year))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

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
            Text(total > 0 ? "\(Int((Double(count) / Double(total) * 100).rounded()))%" : "—")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
