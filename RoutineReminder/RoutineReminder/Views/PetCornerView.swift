import SwiftUI
import SwiftData

/// The companion's little corner: a light, friendly space — never guilt-trippy.
/// The pet's mood reflects today's real completions (your routines are its
/// food), and points unlock new companions and themes. Everything is cosmetic;
/// the app is fully usable ignoring this screen forever.
struct PetCornerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @Query private var routines: [Routine]
    @Query private var contexts: [ContextTag]
    @Query private var completions: [CompletionRecord]

    @State private var bouncing = false
    @State private var showingCareSheet = false

    init() {
        let key = Scheduler.dayKey(for: .now)
        _completions = Query(filter: #Predicate<CompletionRecord> { $0.dayKey == key })
    }

    private var todayProgress: (done: Int, total: Int) {
        let occurrences = Scheduler.occurrences(for: routines, contexts: contexts, on: .now)
        let done = occurrences.filter { occurrence in
            completions.first { $0.routineID == occurrence.routineID && $0.slotMinutes == occurrence.slotMinutes }?.isDone == true
        }.count
        return (done, occurrences.count)
    }

    private var moodLine: String {
        let progress = todayProgress
        if progress.total == 0 { return String(localized: "A quiet day. \(settings.companion.name) approves.") }
        if progress.done == progress.total { return settings.companion.happyLine }
        if Double(progress.done) / Double(progress.total) >= 0.5 { return String(localized: "Almost there — keep going!") }
        return settings.companion.sleepyLine
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // The companion, front and center, gently animated.
                    ZStack {
                        Circle()
                            .fill(settings.theme.gradient.opacity(0.18))
                            .frame(width: 190, height: 190)
                        Text(settings.companion.emoji)
                            .font(.system(size: 96))
                            .scaleEffect(bouncing ? 1.06 : 1.0)
                            .offset(y: bouncing ? -8 : 0)
                            .animation(.spring(duration: 1.4).repeatForever(autoreverses: true), value: bouncing)
                    }
                    .padding(.top, 12)
                    .onAppear { bouncing = true }
                    .accessibilityLabel(Text(String(localized: "\(settings.companion.name), your companion")))

                    VStack(spacing: 6) {
                        Text(settings.companion.name)
                            .font(.title2.bold())
                        Text(moodLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Today's food bowl: real completions feed the pet.
                    let progress = todayProgress
                    if progress.total > 0 {
                        VStack(spacing: 8) {
                            ProgressView(value: Double(progress.done), total: Double(progress.total))
                                .tint(settings.theme.accent)
                            Text(String(localized: "\(progress.done) of \(progress.total) routines done today"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 32)
                    }

                    // Points + next unlock.
                    VStack(spacing: 10) {
                        HStack {
                            Label(String(localized: "\(settings.rewardPoints) points"), systemImage: "sparkles")
                                .font(.headline)
                            Spacer()
                            NavigationLink(String(localized: "Rewards")) {
                                RewardsView()
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                        if let next = nextUnlock {
                            let remaining = next.points - settings.rewardPoints
                            Text(String(localized: "\(remaining) points until \(next.name) \(next.emoji)"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)

                    // Optional: turn pet care into real routines.
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(localized: "Real pet at home?"))
                            .font(.headline)
                        Text(String(localized: "Create feeding or medicine routines — they ride the same reminders and checklist as everything else."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            showingCareSheet = true
                        } label: {
                            Label(String(localized: "Set up a pet care routine"), systemImage: "pawprint.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle(String(localized: "Pet Corner"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingCareSheet) {
                RoutineEditorView(routine: nil, draft: RoutineDraft(
                    title: String(localized: "Feed the pet"),
                    symbol: "pawprint.fill",
                    colorName: "orange",
                    times: [8 * 60, 18 * 60]
                ))
            }
        }
    }

    private var nextUnlock: (name: String, emoji: String, points: Int)? {
        let lockedCompanions = Companion.all.filter { $0.pointsRequired > settings.rewardPoints }
            .map { (name: $0.name, emoji: $0.emoji, points: $0.pointsRequired) }
        let lockedThemes = Theme.all.filter { $0.pointsRequired > settings.rewardPoints }
            .map { (name: $0.name, emoji: "🎨", points: $0.pointsRequired) }
        return (lockedCompanions + lockedThemes).min { $0.points < $1.points }
    }
}

// MARK: - Rewards shelf

struct RewardsView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        List {
            Section {
                Label(String(localized: "\(settings.rewardPoints) points — earn \(AppSettings.pointsPerCompletion) for every completed routine"),
                      systemImage: "sparkles")
                    .font(.subheadline)
            }

            Section(String(localized: "Companions")) {
                ForEach(Companion.all) { companion in
                    let unlocked = settings.isUnlocked(pointsRequired: companion.pointsRequired)
                    Button {
                        if unlocked { settings.companionID = companion.id }
                    } label: {
                        HStack {
                            Text(companion.emoji)
                                .font(.title2)
                                .saturation(unlocked ? 1 : 0)
                            VStack(alignment: .leading) {
                                Text(companion.name)
                                    .foregroundStyle(unlocked ? .primary : .secondary)
                                if !unlocked {
                                    Text(String(localized: "Unlocks at \(companion.pointsRequired) points"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if settings.companionID == companion.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(settings.theme.accent)
                            } else if !unlocked {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                }
            }

            Section(String(localized: "Themes")) {
                ForEach(Theme.all) { theme in
                    let unlocked = settings.isUnlocked(pointsRequired: theme.pointsRequired)
                    Button {
                        if unlocked { settings.themeID = theme.id }
                    } label: {
                        HStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.gradient)
                                .frame(width: 34, height: 34)
                                .saturation(unlocked ? 1 : 0.15)
                            VStack(alignment: .leading) {
                                Text(theme.name)
                                    .foregroundStyle(unlocked ? .primary : .secondary)
                                if !unlocked {
                                    Text(String(localized: "Unlocks at \(theme.pointsRequired) points"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if settings.themeID == theme.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(settings.theme.accent)
                            } else if !unlocked {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                }
            }
        }
        .navigationTitle(String(localized: "Rewards"))
    }
}
