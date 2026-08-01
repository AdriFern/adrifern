# Routine Reminder

A single-user iOS app for organizing recurring routines around real life: daily pills,
every-other-day pet meds, homework on the weeks your daughter is with you, work
reminders, monthly bills — each with a checklist, a notification, or a repeating
alarm you dismiss by marking it done.

Everything is on-device: no accounts, no sync, no servers. The natural-language
Quick Add is parsed offline in **English and Spanish** (zero AI/API cost), and the
whole app is localized in both languages, following the iOS system (or per-app)
language automatically.

## Features

- **Today** — the day's checklist, sorted by time, with overdue highlighting,
  haptic check-off, and a friendly companion in the corner. Marking done cancels
  that occurrence's pending notifications and nags.
- **Flexible schedules** — every day, every other day / every N days, specific
  weekdays, days of the month (29–31 clamp to short months), or one-time; optional
  end dates; multiple times per day.
- **People & Pets (contexts)** — presence patterns: always, alternating weeks with
  an explicit handoff weekday (Friday custody handoffs work), or certain weekdays.
  Linked routines only fire on days they're with you, with an upcoming-weeks preview.
- **Alerts per routine** — silent, notification, or alarm mode: a time-sensitive
  alert that re-alerts (configurable interval and count) until marked done, with
  Mark done (requires unlock) and Snooze actions on the banner. Snoozing pauses and
  restarts the whole chain correctly; opening the app never cancels live reminders.
  A sentinel notification re-arms scheduling if the app isn't opened for ~2 weeks.
- **Calendar** — month grid with routine dots, context week tinting + symbols, and
  a Today button.
- **Multi-step wizard** — What → When → Alerts → Checklist, with validation; editing
  offers Save from any step.
- **Quick Add** — bilingual plain-language parsing with an editable handoff to the
  full editor ("Refine"). Runs entirely on-device.
- **Onboarding** — a fast, bubbly 4-page intro guided by the companion, with
  starter cards and notification permission priming.
- **Rewards** — completions earn points; points unlock accent themes and new
  companions (all cosmetic, all in code, no data weight). Pet corner shows your
  companion's mood based on today's real completions.
- **Settings** — snooze length, alarm re-alert interval/count, any-time reminder
  hour, private notifications (generic lock-screen text), appearance
  (System/Light/Dark), JSON backup export/import.

## Project layout

```
RoutineReminder/
├── RoutineReminder.xcodeproj
├── LAUNCH_GUIDE.md               # App Store launch + monetization playbook
└── RoutineReminder/
    ├── RoutineReminderApp.swift  # Entry; SwiftData container + corruption recovery
    ├── Localizable.xcstrings     # English + Spanish string catalog
    ├── Models/                   # SwiftData models + versioned Schedule/Presence types
    ├── Engine/
    │   ├── Scheduler.swift       # Recurrence + custody-week math (DST-safe)
    │   ├── NotificationManager.swift # Diff-based scheduling, nags, snooze, deep links
    │   ├── QuickAddParser.swift  # Offline EN/ES natural-language parsing
    │   ├── AppSettings.swift     # Settings + rewards (points, themes, companions)
    │   └── DataExport.swift      # JSON backup export/import
    └── Views/                    # Today, Calendar, Routines, wizard, People & Pets,
                                  # Quick Add, Onboarding, Pet Corner, Settings
```

## Building

1. Open `RoutineReminder/RoutineReminder.xcodeproj` in Xcode 16 or newer.
2. Select your development team under Signing & Capabilities (needed for a real
   device; the simulator works without one).
3. Run on iOS 17.0+.

Notes:

- Time Sensitive Notifications and Data Protection entitlements are pre-configured.
- iOS caps pending local notifications at 64; base alerts are scheduled before
  alarm nags across a 14-day window, re-synced whenever the app is active, with a
  day-13 sentinel so reminders can't silently stop.
- True "critical alerts" that override silent mode require a special Apple
  entitlement; alarm mode uses time-sensitive alerts + repeat re-alerts instead.
- See `LAUNCH_GUIDE.md` for the full App Store submission, pricing, listing, and
  QA playbook.
