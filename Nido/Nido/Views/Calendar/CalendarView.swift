import SwiftUI

private struct SelectedDay: Identifiable {
    let key: String
    var id: String { key }
}

struct CalendarView: View {
    @Environment(FamilyStore.self) private var store
    @State private var monthOffset = 0
    @State private var selectedDay: SelectedDay?
    @State private var showPattern = false
    @State private var showInvite = false

    private static let offsetRange = Array(-24...36)
    // Computed so the anchor stays correct if the app lives across a
    // month boundary.
    private var baseMonth: Month { Month.containing(Date()) }

    private var visibleMonth: Month { baseMonth.adding(monthOffset) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                weekdayHeader
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)

                TabView(selection: $monthOffset) {
                    ForEach(Self.offsetRange, id: \.self) { offset in
                        MonthGridView(month: baseMonth.adding(offset)) { dayKey in
                            selectedDay = SelectedDay(key: dayKey)
                        }
                        .padding(.horizontal, 16)
                        .tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Group {
                    if store.assignments.isEmpty {
                        coachingCard
                    } else {
                        legend
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let family = store.family {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                            Text(family.childName)
                                .font(.headline)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        // Fixed-width slot so the button doesn't shift when
                        // the sync spinner appears.
                        ProgressView()
                            .controlSize(.small)
                            .opacity(store.isSyncing ? 1 : 0)
                            .frame(width: 20)
                        Button {
                            showPattern = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                Text("Schedule")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .accessibilityLabel(Text("Set up a repeating schedule"))
                    }
                }
            }
            .sheet(item: $selectedDay) { day in
                DayDetailSheet(dayKey: day.key)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showPattern) {
                PatternSheet()
            }
            .sheet(isPresented: $showInvite) {
                NavigationStack {
                    InviteView(isOnboarding: false)
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Shown once the coaching card has retired, so the bottom of
                // the screen never stacks two cards on small phones.
                if store.family?.partnerHasJoined == false, !store.assignments.isEmpty {
                    inviteBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button {
                withAnimation { monthOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(Theme.cardBackground, in: Circle())
            }
            .disabled(monthOffset <= Self.offsetRange.first!)
            .accessibilityLabel(Text("Previous month"))

            Spacer()

            VStack(spacing: 2) {
                Text(visibleMonth.title)
                    .font(.title3.bold())
                    .contentTransition(.numericText())
                // Always laid out so the header height never jumps mid-swipe.
                Button {
                    withAnimation { monthOffset = 0 }
                } label: {
                    Text("Back to today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .opacity(monthOffset == 0 ? 0 : 1)
                .disabled(monthOffset == 0)
                .accessibilityHidden(monthOffset == 0)
            }

            Spacer()

            Button {
                withAnimation { monthOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(Theme.cardBackground, in: Circle())
            }
            .disabled(monthOffset >= Self.offsetRange.last!)
            .accessibilityLabel(Text("Next month"))
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Array(Month.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                if let family = store.family {
                    let counts = monthCounts
                    LegendChip(
                        name: family.name(of: .parentA),
                        colorHex: family.colorA,
                        count: counts.a
                    )
                    LegendChip(
                        name: family.name(of: .parentB),
                        colorHex: family.colorB,
                        count: counts.b
                    )
                    Spacer()
                    if counts.unassigned > 0 {
                        Text("\(counts.unassigned) unassigned")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            let monthKeys = visibleMonth.dayKeys
            let pendingInMonth = monthKeys.contains { store.pendingDateKeys.contains($0) }
            let notesInMonth = monthKeys.contains { store.notes[$0] != nil }
            if pendingInMonth || notesInMonth {
                HStack(spacing: 14) {
                    if pendingInMonth {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                            Text("awaiting approval")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if notesInMonth {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.secondary)
                                .frame(width: 4, height: 4)
                            Text("note")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private var coachingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let family = store.family {
                Label {
                    Text("Tap any day to choose who has \(family.childName) — or fill in weeks at once with a repeating schedule.")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "hand.tap")
                        .foregroundStyle(Color.accentColor)
                }
                Button {
                    showPattern = true
                } label: {
                    Text("Set up a repeating schedule")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var monthCounts: (a: Int, b: Int, unassigned: Int) {
        var a = 0, b = 0, unassigned = 0
        for key in visibleMonth.dayKeys {
            switch store.assignments[key] {
            case .parentA: a += 1
            case .parentB: b += 1
            case nil: unassigned += 1
            }
        }
        return (a, b, unassigned)
    }

    private var inviteBanner: some View {
        Button {
            showInvite = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your co-parent hasn't joined yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Show the invitation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legend chip

private struct LegendChip: View {
    var name: String
    var colorHex: String
    var count: Int

    var body: some View {
        HStack(spacing: 6) {
            ParentDot(colorHex: colorHex)
            Text(name)
                .font(.caption.weight(.semibold))
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.cardBackground, in: Capsule())
    }
}

// MARK: - Month grid

struct MonthGridView: View {
    @Environment(FamilyStore.self) private var store
    let month: Month
    var onSelect: (String) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<month.leadingBlanks, id: \.self) { index in
                    Color.clear
                        .frame(height: 1)
                        .id("blank-\(index)")
                }
                ForEach(Array(month.dayKeys.enumerated()), id: \.element) { index, dayKey in
                    DayCell(
                        dayNumber: index + 1,
                        owner: store.assignments[dayKey],
                        family: store.family,
                        isToday: dayKey == Day.todayKey,
                        hasNote: store.notes[dayKey] != nil,
                        isPending: store.pendingDateKeys.contains(dayKey)
                    ) {
                        onSelect(dayKey)
                    }
                }
            }
        }
        .scrollBounceBehavior(.always)
        .refreshable {
            await store.refresh()
        }
    }
}

// MARK: - Day cell

struct DayCell: View {
    @Environment(\.colorScheme) private var colorScheme
    let dayNumber: Int
    let owner: ParentRole?
    let family: Family?
    let isToday: Bool
    let hasNote: Bool
    let isPending: Bool
    var action: () -> Void

    private var fillColor: Color {
        guard let owner, let family else {
            return Color(.tertiarySystemFill).opacity(0.5)
        }
        return Theme.dayFill(Color(hex: family.colorHex(of: owner)), scheme: colorScheme)
    }

    private var accessibilityText: String {
        var text: String
        if let owner, let family {
            text = String(localized: "Day \(dayNumber), \(family.name(of: owner))")
        } else {
            text = String(localized: "Day \(dayNumber), unassigned")
        }
        if isPending {
            text += ", " + String(localized: "awaiting approval")
        }
        if hasNote {
            text += ", " + String(localized: "has a note")
        }
        return text
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(dayNumber)")
                    .font(.callout.weight(isToday ? .bold : .medium))
                    .foregroundStyle(owner == nil ? Color.secondary : Color.primary)
                if hasNote {
                    Circle()
                        .fill(.secondary)
                        .frame(width: 4, height: 4)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fillColor)
            )
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isPending {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                        .padding(3)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityText))
    }
}
