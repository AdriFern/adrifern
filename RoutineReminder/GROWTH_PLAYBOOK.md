# RoutineReminder — Growth Playbook

Engagement, retention, and monetization strategy from the growth council
(engagement-mechanics expert + iOS platform-features strategist, both grounded in a
full read of the codebase, benchmarked against Duolingo, Finch, Gentler Streak,
Bears Gratitude, Streaks, Things 3, Flighty, Crouton, and recent Apple Design
Award winners). Monetization evolution synthesized with the App Store strategist's
report from the launch council.

Both experts' headline: **the codebase is unusually ready for this** — complete
per-occurrence history, a presence engine that knows exactly which days were
"yours," a companion with real mood plumbing, and a points economy already exist.
Most proposals are computation + presentation over data the app already logs, not
new infrastructure. Everything below is fully offline and respects the hard
constraints: earnable-only rewards, no guilt mechanics, reminders never paywalled.

---

## 1. The Big Five (highest leverage, in order)

### ① Schedule-aware Gentle Streak + Streak Shields
**Proven by:** Duolingo (streak = their #1 retention feature per their own
published experiments) fixed with Gentler Streak's insight (Apple Watch App of the
Year 2022: streaks that respect rest days).
**In this app:** a "days you showed up" streak where days with *zero scheduled
occurrences* — custody off-weeks, every-other-day gaps — are **neutral**: they
neither extend nor break the streak (shown as small pause/moon dots). A co-parent
can never be punished by the custody calendar; the mechanic reinforces the moat
instead of fighting it. Every 7 counted days banks a **Shield** (cap 3,
auto-consumed overnight on a missed day: "I covered for you yesterday 🛡"), plus an
honest next-morning repair ("Did you actually do it? Mark yesterday done").
Shields are earned, never sold. Pure function over existing CompletionRecords —
no schema change.
**Cost:** M · **Impact on retention:** the single highest of anything on this list.

### ② Interactive widgets + Siri (the friction collapse)
**Proven by:** Duolingo publicly credits its streak widget with major DAU lift;
Streaks and Things 3 sell largely on widgets; LAUNCH_GUIDE already ranked widgets
#1 in earning power.
**In this app:** lock-screen widget with the next occurrence and countdown;
home-screen widget with the companion + streak and **tappable checkboxes** (iOS 17
interactive widgets) that complete a routine without opening the app, writing
through the existing race-safe CompletionStore and feeding the points/pet loop.
Plus App Intents: "Hey Siri, mark pills done," and dictated Quick Add that pipes
Siri input through the existing bilingual parser — **Siri in Spanish, fully
offline** is a listing bullet no competitor has. One prerequisite (~2 days): move
the store to an App Group.
**Cost:** M–L · **Impact:** high on both retention *and* sales (the lock-screen
widget screenshot transforms the paid listing).

### ③ Companion Bond + Day Close ritual (the tasteful Finch layer)
**Proven by:** Finch (repeated App Store Award; the category masterclass in
guilt-free attachment), Bears Gratitude (ADA 2024 — sparse hand-written character
lines carrying an app), Apple's own ring-close celebration.
**In this app:** each companion gains bond levels (1–5, Hatchling → Best Friend)
from lifetime completions — unlocking nothing functional, just bigger bounces and
new dialogue pools, including **custody-aware lines** no competitor can copy:
"Emma comes back Friday — her homework routine wakes up!" And when the last item
of the day is ticked, a once-per-day full-screen **Day Close** moment: companion
jump, code-only confetti physics (SwiftUI Canvas), a designed CoreHaptics
crescendo, the streak ticking up, one contextual line ("That's every Emma-day this
week — 5 for 5"). Peak-end reward stamped exactly on the behavior to repeat.
**Cost:** M · **Impact:** high — this is what makes the app *loved*, which is what
makes it reviewed, which is what makes it sell.

### ④ Handoff Eve brief (the uncopyable ritual)
**Proven by:** nobody — that's the point. Nearest analogues are Headspace's
rituals and Gentler Streak's proactive coaching, both ADA-lauded.
**In this app:** the evening before a presence flip, one gentle notification +
Today-header card: "Emma's week starts tomorrow — homework and 3 other routines
wake up," and at week end a mini "Emma-week closed: 7/7 ✅" arc feeding the streak.
Off-week eve flips to self-care: "Rocky's routines sleep for a week. Anything you
want to add for just-you time?" It ritualizes the emotionally loaded handoff
moment — the actual pain point of co-parenting — and is the App Store story money
shot. Computable exactly from the existing presence engine; one extra local
notification per flip.
**Cost:** M · **Impact:** high; retention loop and differentiator become the same feature.

### ⑤ Monthly Recap + Yearbook (the only marketing channel)
**Proven by:** Spotify Wrapped as the pattern; Duolingo's Year in Review is their
documented top organic-acquisition moment; Gentler Streak's monthly recaps.
**In this app:** on first open of a new month, an optional designed recap card
(ImageRenderer, fully on-device): completions, showed-up days, best streak, "All
14 Emma-days covered," share button with a subtle app mark. December generates a
4-card "Yearbook." A co-parent sharing "every custody day covered" is an
emotionally potent, novel share — and each share is a free, high-trust ad for a
$4.99 app with no marketing budget. Stats framed only as achievements, never as
misses.
**Cost:** M · **Impact:** high on sales specifically.

---

## 2. Release-train roadmap (one headline per release)

**v1.0 — launch (built; tune only):**
- S-sized adds before submission: notification **thread grouping** (nag chains
  stack as one group — protects ratings from the "spam" accusation) +
  **relevanceScore** on overdue nags; **Sparkle completions** (deterministic
  variable rewards: ~1 in 6 check-offs pays 15 points instead of 5, seeded from
  the occurrence ID so it can't be farmed and un-toggling stays symmetric —
  Duolingo's XP-chest mechanic without the gambling); **TipKit** one-shot tips
  funneling buyers to the custody-week moat (undiscovered differentiators produce
  refunds and "just another reminder app" reviews).

**v1.1 — "The Streak & The Widget" (first month):**
- Gentle Streak + Shields, Day Close ritual, App Group migration, interactive
  lock-screen/home widgets, App Shortcuts/Siri (EN+ES). The compounding trio:
  fewer taps → more completions → more points → more attachment. Re-shoot
  screenshots around the lock-screen widget.

**v1.2 — "The Companion Grows" (time against an iOS release window):**
- Bond levels + custody-aware dialogue, Handoff Eve brief, Monthly Recap cards,
  seasonal moments (date-derived, offline, explicitly "returns every year" — no
  FOMO), iOS 18+ Control Center controls / Action Button ("physically click the
  side button to mark morning meds done"), Live Activity + Dynamic Island for
  live alarm chains and next-dose countdowns (Crouton and Flighty both built ADA
  cases on this surface), StandBy bedside variant. **Adopting the newest OS
  surfaces in Apple's launch window is how unknown paid apps get editorially
  featured — worth more sales than any other lever.**

**v1.3 — "On Your Wrist":**
- Apple Watch app + complications, including the **custody ring** (days until
  handoff, in the context's color) — the moat on the watch face. The pure
  Foundation engine files compile for watchOS unchanged; sync rides
  WatchConnectivity + the existing backup DTOs (still no server). Weekly Quests
  board (three deterministic, custody-tuned weekly goals; missed quests silently
  roll over — failure state is silence, never guilt).

**v2.0 — "Two Homes" :**
- CloudKit two-household sync — the only justified subscription (see below).
- December: first Yearbook.

---

## 3. Monetization evolution (with trigger conditions)

1. **Launch:** paid upfront **$3.99 launch week → $4.99**. Positioning: "Pay
   once. No subscription. No account. Nothing leaves your phone." Enable **Family
   Sharing** (goodwill + the second household may get it free — which deepens the
   moat, not cannibalizes it). Generate **offer codes** for co-parenting and pet
   subreddit/Facebook moderators. **Review prompt** (SKStoreReviewController)
   fired only at the third Day Close celebration — ask at the peak moment, never
   after a failure. Regional pricing tiers for Spain + Latin America (the app is
   fully localized — say so in the Spanish listing).
2. **When ~50 ratings at 4.5+ land AND v1.1 widgets ship:** raise to **$5.99**
   ("price rises with value"; early buyers feel rewarded, not milked).
3. **When the rewards economy is proven (reviews mention the companion/themes):**
   add a **Supporter Pack** one-time IAP ($2.99–3.99) in v1.2/1.3 — *additive*
   exclusive cosmetics (a few extra companions/themes) plus a "buy the companion a
   treat" tip-jar framing (Finch's premium-cosmetics-on-a-free-heart model,
   adapted to pay-once). **Never** convert previously earnable items to paid, and
   shields/streaks/reminders stay unbuyable forever.
4. **When reviews repeatedly ask for sync/second-device:** build v2.0 two-household
   CloudKit sync as the subscription — **$9.99/year** (defensible because the
   infra is Apple-hosted and the value is per-family), core app untouched for
   non-subscribers, existing owners keep everything they have.
5. **Ongoing:** pitch App Store editorial at every OS-surface adoption (1.2, 1.3);
   featuring is the single highest-value "campaign" available to a solo paid app.

---

## 4. Do NOT do (review-killers for this specific app)

- **Never sell** streak repairs, shields, or points. The moment consistency is
  purchasable, the custody-immune streak becomes a cynical mechanic and the
  reviews will say so.
- **No subscription on the core app, ever.** Offline single-user utilities that
  add subscriptions are the #1 documented driver of 1-star "cash grab" reviews.
- **No analytics SDK, no ads** — either would falsify the "Data Not Collected"
  label, which is a load-bearing marketing asset.
- **No "we miss you" notifications.** Re-engagement must always carry real
  information (handoff eve, the day-13 scheduling sentinel). Engagement-bait
  pings from a reminder app read as spam and get notifications revoked — death
  for the core product.
- **No FOMO-limited content.** Seasonal items state "returns every year" in the UI.
- **No guilt states.** Missed quests vanish silently; incomplete weeks celebrate
  what *was* done; the pet never sulks, sickens, or dies; off-weeks are "paused,
  not broken."
- **No fake urgency pricing** (countdown sales, strike-through anchor prices).

---

## 5. Sequenced effort summary

| Release | Engineering size | Headline | Primary metric moved |
|---|---|---|---|
| 1.0 tune | ~3 days | Sparkles + tips + grouped nags | Ratings quality |
| 1.1 | ~2–3 weeks | Streak + interactive widget + Siri | D7/D30 retention |
| 1.2 | ~2–3 weeks | Companion bond + handoff ritual + recap + iOS-latest surfaces | Love (reviews) + featuring |
| 1.3 | ~3–4 weeks | Watch + custody ring + quests | Price-point support |
| 2.0 | ~6+ weeks | Two-household sync (subscription) | Revenue |

*Note: the dedicated monetization deep-dive agent hit the session's usage limit;
§3 synthesizes the launch council strategist's monetization report plus the two
completed growth reports. A standalone monetization deep-dive (StoreKit 2 win-back
offers, paywall-view specifics, RevenueCat benchmark data) can be run later if
wanted — the numbers above are conservative and follow proven indie patterns.*
