import Foundation
import SwiftUI

// MARK: - App-wide user settings + rewards
//
// Tiny, local, and observable. Values live in UserDefaults — a handful of
// integers and strings, so the rewards layer adds no meaningful data weight.

final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private static let defaults = UserDefaults.standard

    @Published var hasOnboarded: Bool { didSet { Self.defaults.set(hasOnboarded, forKey: "hasOnboarded") } }
    @Published var snoozeMinutes: Int { didSet { Self.defaults.set(snoozeMinutes, forKey: "snoozeMinutes") } }
    @Published var nagIntervalMinutes: Int { didSet { Self.defaults.set(nagIntervalMinutes, forKey: "nagIntervalMinutes") } }
    @Published var nagCount: Int { didSet { Self.defaults.set(nagCount, forKey: "nagCount") } }
    @Published var anyTimeReminderMinutes: Int { didSet { Self.defaults.set(anyTimeReminderMinutes, forKey: "anyTimeReminderMinutes") } }
    @Published var privateNotifications: Bool { didSet { Self.defaults.set(privateNotifications, forKey: "privateNotifications") } }
    @Published var appearance: Appearance { didSet { Self.defaults.set(appearance.rawValue, forKey: "appearance") } }
    @Published var themeID: String { didSet { Self.defaults.set(themeID, forKey: "themeID") } }
    @Published var companionID: String { didSet { Self.defaults.set(companionID, forKey: "companionID") } }
    @Published var rewardPoints: Int { didSet { Self.defaults.set(rewardPoints, forKey: "rewardPoints") } }

    private init() {
        let d = Self.defaults
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        snoozeMinutes = d.object(forKey: "snoozeMinutes") as? Int ?? 10
        nagIntervalMinutes = d.object(forKey: "nagIntervalMinutes") as? Int ?? 5
        nagCount = d.object(forKey: "nagCount") as? Int ?? 3
        anyTimeReminderMinutes = d.object(forKey: "anyTimeReminderMinutes") as? Int ?? 9 * 60
        privateNotifications = d.bool(forKey: "privateNotifications")
        appearance = Appearance(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        themeID = d.string(forKey: "themeID") ?? Theme.defaultTheme.id
        companionID = d.string(forKey: "companionID") ?? Companion.defaultCompanion.id
        rewardPoints = d.object(forKey: "rewardPoints") as? Int ?? 0
    }

    var theme: Theme { Theme.all.first { $0.id == themeID } ?? .defaultTheme }
    var companion: Companion { Companion.all.first { $0.id == companionID } ?? .defaultCompanion }

    // MARK: Rewards

    static let pointsPerCompletion = 5

    func awardCompletion() {
        rewardPoints += Self.pointsPerCompletion
    }

    /// Un-completing takes the points back so toggling can't farm rewards.
    func revokeCompletion() {
        rewardPoints = max(0, rewardPoints - Self.pointsPerCompletion)
    }

    func isUnlocked(pointsRequired: Int) -> Bool {
        rewardPoints >= pointsRequired
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Themes (unlockable accent looks)
//
// Cosmetic only — every feature works on the default theme. Defined entirely
// in code: no assets, no downloads, no data weight.

struct Theme: Identifiable, Equatable {
    let id: String
    let name: String
    let accent: Color
    let gradientEnd: Color
    let pointsRequired: Int

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, gradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let defaultTheme = Theme(id: "fresh", name: String(localized: "Fresh"),
                                    accent: Color(red: 0.35, green: 0.40, blue: 0.90),
                                    gradientEnd: Color(red: 0.18, green: 0.77, blue: 0.71),
                                    pointsRequired: 0)

    static let all: [Theme] = [
        .defaultTheme,
        Theme(id: "forest", name: String(localized: "Forest"),
              accent: Color(red: 0.16, green: 0.55, blue: 0.39),
              gradientEnd: Color(red: 0.55, green: 0.78, blue: 0.35), pointsRequired: 50),
        Theme(id: "sunset", name: String(localized: "Sunset"),
              accent: Color(red: 0.95, green: 0.45, blue: 0.30),
              gradientEnd: Color(red: 0.98, green: 0.72, blue: 0.30), pointsRequired: 100),
        Theme(id: "ocean", name: String(localized: "Ocean"),
              accent: Color(red: 0.10, green: 0.45, blue: 0.85),
              gradientEnd: Color(red: 0.25, green: 0.80, blue: 0.95), pointsRequired: 200),
        Theme(id: "berry", name: String(localized: "Berry"),
              accent: Color(red: 0.85, green: 0.30, blue: 0.55),
              gradientEnd: Color(red: 0.98, green: 0.60, blue: 0.75), pointsRequired: 300),
        Theme(id: "graphite", name: String(localized: "Graphite"),
              accent: Color(red: 0.35, green: 0.38, blue: 0.45),
              gradientEnd: Color(red: 0.60, green: 0.65, blue: 0.75), pointsRequired: 400),
        Theme(id: "midnight", name: String(localized: "Midnight"),
              accent: Color(red: 0.42, green: 0.35, blue: 0.95),
              gradientEnd: Color(red: 0.75, green: 0.30, blue: 0.85), pointsRequired: 600),
    ]
}

// MARK: - Companions (unlockable buddies)
//
// A small friendly character that guides onboarding, lives in the Today
// header, and hangs out in its corner. Emoji-based: zero assets, zero data.

struct Companion: Identifiable, Equatable {
    let id: String
    let name: String
    let emoji: String
    let pointsRequired: Int
    let happyLine: String
    let sleepyLine: String

    static let defaultCompanion = Companion(id: "chick", name: String(localized: "Pip"), emoji: "🐣",
                                            pointsRequired: 0,
                                            happyLine: String(localized: "Look at you go!"),
                                            sleepyLine: String(localized: "We've got this. One thing at a time."))

    static let all: [Companion] = [
        .defaultCompanion,
        Companion(id: "dog", name: String(localized: "Biscuit"), emoji: "🐶", pointsRequired: 75,
                  happyLine: String(localized: "Best day ever. Again!"),
                  sleepyLine: String(localized: "A little walk through the list?")),
        Companion(id: "cat", name: String(localized: "Mochi"), emoji: "🐱", pointsRequired: 150,
                  happyLine: String(localized: "Acceptable. Very acceptable."),
                  sleepyLine: String(localized: "Nap later. Checklist first.")),
        Companion(id: "fox", name: String(localized: "Rusty"), emoji: "🦊", pointsRequired: 250,
                  happyLine: String(localized: "Sly and productive!"),
                  sleepyLine: String(localized: "Let's outfox that list.")),
        Companion(id: "turtle", name: String(localized: "Sheldon"), emoji: "🐢", pointsRequired: 350,
                  happyLine: String(localized: "Slow and steady wins."),
                  sleepyLine: String(localized: "No rush. Just start.")),
        Companion(id: "owl", name: String(localized: "Sage"), emoji: "🦉", pointsRequired: 500,
                  happyLine: String(localized: "Wise choices all day."),
                  sleepyLine: String(localized: "A wise bird ticks one box at a time.")),
        Companion(id: "dragon", name: String(localized: "Ember"), emoji: "🐲", pointsRequired: 750,
                  happyLine: String(localized: "Legendary streak!"),
                  sleepyLine: String(localized: "Even dragons start small.")),
    ]
}
