import SwiftUI
import SwiftData

/// First-launch onboarding: four quick, skippable pages guided by the
/// companion. Friendly and bouncy, never gamer-y. Ends with notification
/// priming (explain first, then the system prompt) — the moment that decides
/// whether a reminder app can do its job.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: AppSettings

    @State private var page = 0
    @State private var bouncing = false
    @State private var selectedStarters: Set<String> = []

    private let pages = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages - 1 {
                    Button(String(localized: "Skip")) { finish() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }

            TabView(selection: $page) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                startersPage.tag(2)
                notificationsPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(duration: 0.5), value: page)

            // Progress dots that fill with a little spring.
            HStack(spacing: 10) {
                ForEach(0..<pages, id: \.self) { index in
                    Circle()
                        .fill(index <= page ? settings.theme.accent : Color(.systemGray4))
                        .frame(width: index == page ? 12 : 8, height: index == page ? 12 : 8)
                        .animation(.spring(duration: 0.35), value: page)
                }
            }
            .padding(.bottom, 18)
            .accessibilityLabel(Text(String(localized: "Step \(page + 1) of \(pages)")))

            footerButton
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { bouncing = true }
    }

    // MARK: Pages

    private var companionHero: some View {
        ZStack {
            Circle()
                .fill(settings.theme.gradient.opacity(0.2))
                .frame(width: 170, height: 170)
            Text(settings.companion.emoji)
                .font(.system(size: 86))
                .scaleEffect(bouncing ? 1.07 : 1.0)
                .offset(y: bouncing ? -6 : 0)
                .animation(.spring(duration: 1.2).repeatForever(autoreverses: true), value: bouncing)
        }
        .accessibilityHidden(true)
    }

    private var welcomePage: some View {
        VStack(spacing: 22) {
            Spacer()
            companionHero
            Text(String(localized: "Hi! I'm \(settings.companion.name) 🎈"))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(String(localized: "Life's a juggle — pills, homework, pet days, rent. Let's catch things before they drop."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
        }
    }

    private var howItWorksPage: some View {
        VStack(spacing: 26) {
            Spacer()
            Text(String(localized: "Three little things"))
                .font(.title.bold())
            VStack(alignment: .leading, spacing: 20) {
                onboardingRow(symbol: "sparkles",
                              title: String(localized: "Just type it"),
                              text: String(localized: "\"Pills every day at 8\" — understood right on your phone."))
                onboardingRow(symbol: "figure.2.and.child.holdinghands",
                              title: String(localized: "It knows whose week it is"),
                              text: String(localized: "Kids on alternating weeks? A pet with every-other-day meds? Reminders fire only on the right days."))
                onboardingRow(symbol: "checklist",
                              title: String(localized: "Check it off, feel great"),
                              text: String(localized: "Checklists, gentle nags until it's done, and a happy \(settings.companion.name) when you finish."))
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    private func onboardingRow(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(settings.theme.gradient, in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var startersPage: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(String(localized: "Who's in your world?"))
                .font(.title.bold())
            Text(String(localized: "Pick any that fit — I'll set them up so you can add their week patterns later. Totally optional!"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                starterCard(id: "child", emoji: "🧒", label: String(localized: "A kid part-time"))
                starterCard(id: "pet", emoji: "🐾", label: String(localized: "A shared pet"))
                starterCard(id: "meds", emoji: "💊", label: String(localized: "Daily meds"))
                starterCard(id: "me", emoji: "🙋", label: String(localized: "Just me"))
            }
            .padding(.horizontal, 28)
            Spacer()
        }
    }

    private func starterCard(id: String, emoji: String, label: String) -> some View {
        let selected = selectedStarters.contains(id)
        return Button {
            withAnimation(.spring(duration: 0.3)) {
                if selected { selectedStarters.remove(id) } else { selectedStarters.insert(id) }
            }
        } label: {
            VStack(spacing: 8) {
                Text(emoji).font(.system(size: 40))
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(selected ? settings.theme.accent.opacity(0.18) : Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(selected ? settings.theme.accent : .clear, lineWidth: 2)
            }
            .scaleEffect(selected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private var notificationsPage: some View {
        VStack(spacing: 22) {
            Spacer()
            companionHero
            Text(String(localized: "One last thing"))
                .font(.title.bold())
            Text(String(localized: "To tap you on the shoulder at the right moment — \"pills, 8:00!\" — I need permission to send notifications. That's the whole job!"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
        }
    }

    // MARK: Footer

    private var footerButton: some View {
        Button {
            if page == 2 { createStarters() }
            if page < pages - 1 {
                page += 1
            } else {
                NotificationManager.shared.requestAuthorization()
                finish()
            }
        } label: {
            Text(page == pages - 1 ? String(localized: "Turn on reminders") : String(localized: "Continue"))
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(settings.theme.accent)
    }

    private func createStarters() {
        if selectedStarters.contains("child") {
            var pattern = PresencePattern()
            pattern.kind = .alternatingWeeks
            let context = ContextTag(name: String(localized: "My kid"), symbol: "figure.child",
                                     colorName: "purple", pattern: pattern)
            modelContext.insert(context)
        }
        if selectedStarters.contains("pet") {
            var pattern = PresencePattern()
            pattern.kind = .alternatingWeeks
            let context = ContextTag(name: String(localized: "My pet"), symbol: "pawprint.fill",
                                     colorName: "orange", pattern: pattern)
            modelContext.insert(context)
        }
        if selectedStarters.contains("meds") {
            let routine = Routine(title: String(localized: "Take my meds"),
                                  symbol: "pills.fill", colorName: "teal",
                                  timesMinutes: [8 * 60], alertMode: .alarm)
            modelContext.insert(routine)
        }
        try? modelContext.save()
    }

    private func finish() {
        settings.hasOnboarded = true
        NotificationManager.shared.syncAll()
    }
}
