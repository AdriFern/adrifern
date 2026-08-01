# RoutineReminder — Launch & Monetization Guide

Prepared by the expert-council review (7 code/UX/security reviewers + 1 App Store
strategist). Updated to reflect the fixes already applied in this repository.

---

## 1. Where the app stands

**Fixed in code after the council review** (this repo):

- Notification engine rebuilt: diff-based re-sync (opening the app no longer kills
  snoozes or alarm nags), snooze silences and restarts the nag chain, deterministic
  identifiers, delivered banners cleared on completion, base alerts prioritized over
  nags in the 64-notification budget, "keep reminders running" sentinel at day 13.
- Data safety: versioned forward-compatible schedule/pattern decoding (future app
  updates can't reset user data), checklist edits preserve identity (no more progress
  wipes), completion records cleaned up on deletion, duplicate-proof completion
  upsert, database-corruption recovery instead of a crash loop, JSON backup
  export/import.
- Correctness: DST-safe fire times, monthly 29–31 clamps to the last day of the
  month, custody weeks use an explicit handoff weekday (Friday handoffs now work;
  boundaries no longer shift with device locale), empty weekly/monthly schedules
  blocked, Today snaps to the current day on wake, overdue styling.
- Quick Add parser: word-boundary and a.m./p.m. fixes, original-case titles, PM
  heuristic for bare hours, "next Friday" logic, dangling-word cleanup, full
  **Spanish** phrasing support, "Refine in editor" handoff.
- UX/polish: onboarding with notification priming, honest alarm copy, private-
  notifications option, configurable snooze/nag/any-time hour, appearance setting
  (System/Light/Dark), rewards (points → themes & companions), pet corner,
  accessibility labels + Dynamic Type scaling, haptic completion feedback,
  locale-aware weekday order, calendar Today button.
- Store compliance: 1024 px app icon, privacy manifest, time-sensitive + data-
  protection entitlements, English + Spanish localization, honest privacy copy,
  medical-adjacency disclaimer.

**Still required before submission (only possible on your Mac / accounts):**

1. **Build in Xcode 16+** — the code has never been compiled; budget half a day for
   first-build fallout.
2. **Physical-device QA** — the checklist in §5. Notification behavior cannot be
   validated in the simulator.
3. Apple Developer Program enrollment and App Store Connect setup (§2).
4. Screenshots + final listing copy (§4).

---

## 2. Exact path to a live paid listing (3–5 weeks realistic)

### Step 1 — Apple Developer Program (gates everything; start immediately)
1. Enroll at developer.apple.com — **$99/year**, individual enrollment (your legal
   name shows as seller). Approval usually 24–48 h.
2. **Right after approval:** App Store Connect → Business → accept the **Paid
   Applications Agreement** and complete **banking + tax** forms. A paid app cannot
   go live without this and processing takes days — run it in parallel with QA.

### Step 2 — Project prep (Xcode 16+, on a Mac)
1. Target → Signing & Capabilities → Automatically manage signing → pick your team.
   Confirm **Time Sensitive Notifications** and **Data Protection** capabilities
   appear (both are pre-declared in `RoutineReminder.entitlements`). No special
   Apple approval is needed for time-sensitive (unlike Critical Alerts).
2. Bundle ID `com.adrifern.RoutineReminder` — change now if you want; it's
   permanent once the app record exists.
3. Build; fix any first-compile fallout. Two spots the council flagged to verify:
   `#Predicate` generic inference in `CompletionStore`/`NotificationManager`, and
   Swift 6 toolchain features (the project format already requires Xcode 16).
4. The project ships **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`) so 13-inch iPad
   screenshots aren't required at submission; it still runs on iPad in
   compatibility mode. Go universal in 1.1 after a real iPad layout pass.
5. Answer the export-compliance question in App Store Connect with **"None of the
   algorithms mentioned"** (the app uses no non-exempt encryption) — or add
   `ITSAppUsesNonExemptEncryption = NO` to the Info tab to skip the per-build prompt.
6. Marketing version 1.0, build 1; bump the build number on every upload.

### Step 3 — App Store Connect record
1. Apps → + → New App: iOS, name (see §4), primary language English (add Spanish
   localization to the listing too — the app is fully bilingual), bundle ID, any SKU.
2. **Category: Productivity** (secondary Lifestyle). **Do not choose Medical** —
   pill reminders in Medical invite Guideline 1.4.1 scrutiny; Productivity is the
   standard home for reminder apps.
3. **Price:** see §3. Start US/UK/CA/AU/EU + Spain & Latin America (you're bilingual!).
4. **App Privacy: "Data Not Collected."** Truthful (zero networking code — verified
   by the security audit) and a rare, credible marketing asset.
5. **Privacy Policy URL + Support URL** (required even with no collection): a
   one-page GitHub Pages site is enough. One hour of work.
6. Age rating: all "None" → 4+.

### Step 4 — TestFlight
1. Product → Archive → Distribute App → App Store Connect → Upload.
2. Internal testing on your own device immediately; recruit 5–10 external testers
   (co-parenting and pet-owner communities are ideal) — external TestFlight runs a
   light Beta App Review that also smoke-tests acceptance.
3. Run the §5 QA checklist **on a physical device**.

### Step 5 — Submission
Attach the build, fill the listing, and paste review notes:

> "Fully offline reminder app. No account or login. The natural-language Quick Add
> is a rule-based parser running on-device — no AI service, no network calls.
> Time-sensitive notifications are used for user-scheduled routine alarms the user
> explicitly opts into per routine. To test: finish onboarding, then type 'Take my
> pills every day at 8am' in Quick Add (+ menu → Quick Add)."

**Review pitfalls specific to this app:**
- Don't market "breaks through Focus" as a headline claim in metadata (in-app copy
  is already appropriately conditional).
- Never use "prescription," "dosage," "treatment," or outcome claims. Say
  "medication reminders," never "medication management."
- Paid apps get a stricter completeness look (Guideline 4.2/2.1) — the crash risk
  of a never-compiled app is the biggest danger; TestFlight externally first.
- "Alarm" naming: keep metadata honest ("repeat alerts until you mark it done"),
  matching the app's own copy. A reviewer testing silent mode is a real scenario.

Review time is typically 24–48 h. Choose **Manual release**.

---

## 3. Monetization recommendation

| Model | Verdict for v1 |
|---|---|
| **Paid upfront $4.99** | ✅ **Recommended.** Zero extra code, matches the offline/no-account architecture, and the co-parenting niche is drowning in $100+/yr subscription platforms — a pay-once app is a relief. Comparables: Due ~$7.99, Streaks $4.99. |
| Freemium + lifetime IAP | Better long-term revenue but needs 1–2 weeks of StoreKit work + paywall UI. Do it later, if ever — paid→free migration is easy, the reverse angers users. |
| Subscription | ❌ Wrong for v1: no sync, no server, no recurring cost to justify it. #1 driver of 1-star "cash grab" reviews on utilities. |

**Launch plan:** $3.99 launch week → settle at **$4.99** → consider $5.99 once
reviews accumulate. The **rewards/cosmetics system now in the app is deliberately
earnable-only** — it builds goodwill and stickiness; a paid "supporter pack" of
bonus themes/companions is a clean future IAP that never paywalls the reminders.

**The one legitimate future subscription:** two-household sync (CloudKit) — co-parents
in two homes sharing a custody-aware schedule would pay monthly for that. v2 territory.

**Honest revenue expectation:** niche paid utilities from unknown solo developers do
5–30 sales/day at steady state when App Store search lands. Hundreds of dollars per
month, not thousands, until word-of-mouth compounds — but the custody-week mechanic
has almost no direct competition, and that's the moat.

---

## 4. App Store listing kit

### Name options (30 chars max; App Store Connect acceptance is the ground truth)
1. **"OnWeeks: Routines & Reminders"** — coined, evokes on-weeks/off-weeks. Top pick.
2. **"WeekSplit — Family Routines"**
3. **"Routina: Reminders & Weeks"**
4. "Every Other Day" (charming fallback)

"RoutineReminder" as-is is too generic to be granted — pick a brand before the
Connect record. (Also grab the matching .app/.com domain for the support page.)

### Subtitle
"Reminders for custody weeks" — or broader: "Pills, pets & shared weeks"

### Keyword field (≤100 chars, no spaces after commas)
```
pill,meds,medication,pet,dog,cat,coparenting,divorce,checklist,habit,alarm,nag,chores,adhd,schedule
```

### Promo text
> The reminder app that knows whose week it is. Pills, pet meds, homework, rent —
> with custody-week schedules, checklists, and alerts that repeat until you mark
> them done.

### Description skeleton
Open with the differentiator ("Some routines don't happen every day. They happen
every other day — or only on the weeks your kid is with you."), then sections:
People & Pets week patterns → schedules that match reality → alerts that don't give
up → checklists → just type it (EN+ES, on-device) → calendar that shows whose week
it is → your cheerful companion & rewards → private by architecture ("Pay once. No
subscription. No account. No ads. No analytics."). Close with the audience line.
Compliance: no dosage/treatment language, no "bypasses Focus," no health claims.
Provide the Spanish listing too — the app is fully localized.

### Screenshots (6.9" iPhone, portrait; stage demo data first: "Emma," "Rocky," a 3-pill morning routine, rent, skincare)
1. **Person editor with the Upcoming-weeks preview** — the hero. "Set custody weeks once. Correct forever."
2. Today view mid-day with context chip and expanded checklist. "Your whole day, one checklist."
3. Calendar with tinted alternating weeks. "See whose week it is at a glance."
4. Quick Add with a parsed sentence. "Just type it — understood on your phone."
5. Lock screen with an alarm notification + Done/Snooze buttons (shoot on a real device). "Alerts that repeat until you mark them done."
6. Pet corner / rewards. "Little wins add up."

### What's New (1.0)
> Initial release: custody-week-aware routines, every-N-day schedules, checklists,
> repeat-alert alarm mode, bilingual Quick Add (English & Spanish), rewards, and a
> tiny companion who cheers you on.

---

## 5. Pre-launch QA checklist (physical device)

**Build & submission**
- [ ] Clean build on Xcode 16; archive passes App Store Connect validation
- [ ] Team set; Time Sensitive + Data Protection capabilities present in the built
      app (`codesign -d --entitlements -` on the .app)
- [ ] App icon renders on device and in TestFlight
- [ ] Paid Apps Agreement active; banking/tax complete; price set
- [ ] Privacy label "Data Not Collected"; privacy policy + support URLs live

**Onboarding & localization**
- [ ] Fresh install → onboarding appears once; Skip works; starter cards create the
      right contexts/routine; permission prompt only fires from the last page
- [ ] Device set to Spanish → whole app + Quick Add examples + parser work in Spanish
- [ ] Delete + reinstall → onboarding shows again (local data wiped)

**Notification core**
- [ ] Notification fires at the scheduled minute; **Mark done** from the (unlocked)
      lock screen writes the completion and cancels nags; **Done requires unlock**
- [ ] Snooze, then open the app before it elapses → snoozed reminder STILL fires
- [ ] Snooze on an alarm routine → no nag at +5; chain restarts after the snooze
- [ ] Mark done after snoozing → snoozed reminder does NOT fire
- [ ] Alarm: initial + nags at the configured interval; marking done after nag #1
      cancels the rest and clears delivered banners
- [ ] Open the app between the alert and a nag → remaining nags still arrive
- [ ] Tap a notification body → app opens on Today
- [ ] Private notifications ON → banners show generic text
- [ ] Day 13 sentinel appears in pending list (`getPendingNotificationRequests` in
      a debug print, or wait it out in TestFlight)

**Scheduling math**
- [ ] Every-other-day anchored correctly; alternating weeks 1/1 and 2/2 with a
      **Friday handoff** flip on Friday, matching the Upcoming-weeks preview
- [ ] Anchor date in a future week and months in the past both render correctly
      across a year boundary
- [ ] Monthly on the 31st fires Feb 28/29, Apr 30
- [ ] Weekly/monthly with no days selected cannot be saved
- [ ] Context-linked routine on an away day: absent everywhere, no notification
- [ ] End date respected; "Ends" toggle stores a real date without touching the picker

**Quick Add (run every built-in example, EN + ES)**
- [ ] "every 2 days" ≠ 2:00; "at 4 p.m." = 16:00; "Feed the cat 2 scoops every
      morning" keeps its title and parses 8:00 daily
- [ ] "Give Rocky his pill…" preserves "Rocky" capitalization
- [ ] "on friday at 8am" said on a Friday morning → next Friday
- [ ] Garbage input → Save disabled, no crash; Refine opens the editor pre-filled

**Data integrity**
- [ ] Edit a routine mid-day with partial checklist progress → progress survives
- [ ] Delete a person with linked routines → confirmation offers both options
- [ ] Export backup → wipe app → import → everything back
- [ ] Force-quit + relaunch → data persists; rapid checkbox toggling → no duplicate
      records, points stay consistent

**Presentation**
- [ ] Dark mode every screen; Dynamic Type at XXL (grids cap gracefully); VoiceOver
      can complete a routine, tick a checklist item, and navigate the calendar
- [ ] Screenshots match the shipping build

---

## 6. Post-launch roadmap (in earning-power order)

1. **Widgets + lock-screen widgets** (most-cited paid-app feature in this category)
2. History & streaks view (the data is already logged)
3. Per-occurrence skip/reschedule-once (first thing real usage demands)
4. Optional Face ID app lock (custody data privacy)
5. Apple Watch app / complications
6. Two-household CloudKit sync — the future subscription, if ever
