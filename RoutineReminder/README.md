# Routine Reminder

A single-user iOS app for organizing recurring routines around real life: daily pills,
every-other-day pet meds, homework on the weeks your daughter is with you, work
reminders on specific weekdays, monthly bills — each with a checklist, a notification,
or a nagging alarm you dismiss by marking it done.

Everything is on-device: no accounts, no sync, no servers, and the natural-language
Quick Add is parsed offline (zero AI/API cost).

## Features

- **Today** — the day's checklist, sorted by time. Tap to mark done, or expand a
  routine's checklist and tick off individual steps (each morning pill, each homework
  subject). Marking done cancels that occurrence's pending notifications and nags.
- **Flexible schedules** — every day, every other day / every N days (counted from a
  start date), specific weekdays, specific days of the month, or one-time. Optional
  end dates.
- **People & Pets (contexts)** — define who follows a presence pattern: *always*,
  *alternating weeks* (e.g. 1 week on / 1 week off shared custody, with a preview of
  upcoming weeks), or *certain weekdays*. Link routines to a person or pet and the
  reminders only fire on days they're actually with you. Daughter week and pet week
  can alternate automatically, forever, from a single anchor date.
- **Alerts per routine** — silent (checklist only), a normal notification, or **alarm
  mode**: a time-sensitive alert that breaks through Focus and re-notifies every
  5 minutes (3 times) until marked done. Notifications have **Mark done** and
  **Snooze 10 min** actions right on the banner.
- **Calendar** — month view with a dot per scheduled routine and a background tint
  showing whose week/day it is.
- **Multi-step wizard** — What → When → Alerts → Checklist, for guided setup.
- **Quick Add** — type things like:
  - "Remind me to apply skincare every other day starting tonight"
  - "Take my pills every day at 8am"
  - "Homework at 5pm when I have Emma"
  - "Give Rocky his pill every 2 days at 7pm"
  - "Pay rent monthly on the 1st"

  A rule-based parser (all offline) turns that into a schedule and shows an editable
  preview before saving.

## Project layout

```
RoutineReminder/
├── RoutineReminder.xcodeproj
└── RoutineReminder/
    ├── RoutineReminderApp.swift      # App entry; SwiftData container; notification wiring
    ├── Models/
    │   ├── Models.swift              # Routine, ChecklistItem, ContextTag, CompletionRecord (SwiftData)
    │   └── Schedule.swift            # Schedule + PresencePattern + AlertMode value types
    ├── Engine/
    │   ├── Scheduler.swift           # Recurrence + context-presence math, occurrence generation
    │   ├── NotificationManager.swift # Local notifications, alarm nags, Done/Snooze actions
    │   └── QuickAddParser.swift      # Offline natural-language parsing
    └── Views/                        # Today, Calendar, Routines, wizard, People & Pets, Quick Add, Settings
```

## Building

1. Open `RoutineReminder/RoutineReminder.xcodeproj` in Xcode 16 or newer.
2. Select your development team under Signing & Capabilities (needed for a real
   device; the simulator works without one).
3. Run on iOS 17.0+.

Notes:

- The Time Sensitive Notifications capability is pre-configured in
  `RoutineReminder.entitlements` for alarm mode.
- Local notifications are capped at 64 pending by iOS, so the app schedules the
  nearest occurrences over the next 14 days and re-syncs every time it becomes
  active or anything changes.
- True "critical alerts" that override Silent mode require a special entitlement
  from Apple; alarm mode uses time-sensitive alerts + repeat nags instead.

## Possible future upgrades

- Shared/synced schedules between two households (CloudKit)
- An optional LLM-backed Quick Add for more free-form phrasing
- Widgets / lock-screen complications for today's checklist
