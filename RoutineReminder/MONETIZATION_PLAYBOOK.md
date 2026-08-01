# RoutineReminder — Monetization Deep-Dive

Specialist report from the monetization strategist (benchmarked against Due,
Streaks, Structured, Finch, Fantastical, Carrot Weather, and RevenueCat's State
of Subscription Apps data; grounded in a full read of the codebase and the
existing GROWTH_PLAYBOOK). This deepens and corrects GROWTH_PLAYBOOK §3.

**Three corrections to the earlier playbook up front:**

1. **"Offer codes" for a paid app are actually promo codes.** App Store offer
   codes exist only for subscriptions. Paid apps get **promo codes**: 100 per
   app version, each grants a free download, expiring 28 days after generation.
   The community-seeding intent survives; the mechanics change (§1.2).
2. **The sync subscription should be $14.99/yr per family, not $9.99** — the
   corridor set by what co-parents already pay (OurFamilyWizard ~$144+/yr *per
   parent*) makes the delta invisible, and per-family (one parent subscribes,
   the other joins via CloudKit share link free) matches both the technology
   and the sociology (§4).
3. **The Supporter Pack window is v1.1, not v1.2/1.3.** The earnable catalog
   maxes out at 750 points ≈ 4–6 weeks for an engaged user — your most attached
   users hit a dead rewards shelf in month two. Ship the pack while the shelf
   is alive, and extend the earnable ladder in v1.2 (§2).

---

## 1. Launch-phase tactics

### 1.1 Intro pricing mechanics
- Paid-app price changes are scheduled in App Store Connect, go live without
  review, and the store never displays an old price — no accidental fake-anchor.
- Honest launch pricing: **$3.99**, with the fact stated in the promo text
  field: "Launch price — goes to $4.99 on [date]." True, dated information ≠
  manufactured urgency. Keep pricing talk out of the app itself.
- Schedule the rise for **day 10–14** (captures the launch long tail).
- Price changes never affect existing buyers — every increase is automatically
  "early buyers rewarded"; say so in release notes.

### 1.2 Promo codes for niche communities
- 100 per version (a bugfix release mints 100 more), expire 28 days after
  generation — create in batches of 10–20. This is the entire "influencer budget."
- Priority targets: (1) r/coparenting, r/Divorce, r/SingleParents and closed
  co-parenting Facebook groups — approach moderators transparently, 5 codes for
  mods + 10 for a pinned giveaway; the "Data Not Collected, pay once" story is
  the credibility. Same play in Spanish-language co-parenting groups, where
  nobody pitches and you're one of few localized options. (2) Shared-pet and
  pet-med communities (the every-other-day meds hook). (3) ADHD communities
  (the repeat-until-done alarm hook). (4) Micro-press: Club MacStories, r/apple
  indie threads, 9to5Mac/iMore tip lines, Applesfera (ES).
- Include redemption instructions with every code. Don't mass-give: 100 copies
  concentrated on likely reviewers beats 100 scattered. (TestFlight testers
  cannot leave reviews — promo-code redeemers can.)

### 1.3 App Store featuring — the actual mechanism
- **Featuring Nominations** in App Store Connect (plus the promote form at
  developer.apple.com/contact/app-store/promote/). Submit 6–8 weeks ahead.
- Submit three separate nominations: **launch** (lead with "the first reminder
  app with custody-week-aware schedules," then the editorial checklist: offline,
  Data Not Collected, full EN+ES incl. on-device Spanish NLP, Dynamic Type +
  VoiceOver, no ads/subscription); **cultural moments** (Single Parents' Day
  March 21, back-to-school August, National Pet Month); **OS-surface adoption**
  at v1.2 — the highest-probability path for an unknown paid app.
- Nominate in the US **and** Spain/Mexico storefronts — far less editorial
  competition in Spanish-language storefronts, and the localization claim is rare.
- It's a lottery ticket costing one hour per cycle with the highest EV of any
  "campaign" available. Expect nothing; submit every cycle.

### 1.4 Review prompt — Day Close timing + real SKStoreReviewController rules
- System decides whether the sheet shows; max **3 displayed prompts per user per
  365 days**; you can't know the outcome. Use SwiftUI's
  `@Environment(\.requestReview)`, never from a button.
- Fire when ALL hold: today's all-done banner shown (the peak moment — the hook
  already exists in TodayView) AND lifetime completions ≥ ~20 with ≥ 5 distinct
  active days AND ≥ 7 days since install AND ≥ 90 days since last attempt with
  < 3 attempts/365 (track attempts yourself in UserDefaults). Delay ~2s so it
  doesn't stomp the confetti; never in the same session as a permission prompt.
- Budget: attempt #1 at the trigger; #2 after v1.1's first all-done day; #3 in
  reserve for v1.2.
- Add a manual "Rate RoutineReminder" row in Settings → About (write-review deep
  link — doesn't count against the 3-prompt budget), with a plain "Something
  wrong? Email me" link beside it. Do **not** sentiment-gate ("Enjoying the
  app?" → route sad users away) — Apple now frowns on it and it's off-brand.

---

## 2. The Supporter Pack (cosmetics as revenue) — v1.1

**The Finch lesson, translated to pay-once: two permanently separate lanes.**
- **Lane 1 (earned):** the existing 7 themes / 7 companions, points-only,
  forever. Never sell points, never sell unlock-alls.
- **Lane 2 (supporter):** new, additive items never in the earnable catalog,
  purchase-only, framed as a thank-you. Nothing functional.

**Contents ("Supporter Pack" — non-consumable, $2.99, Family Sharing on):**
- 3 supporter companions (same Companion structure; give them the *best*
  custody-aware dialogue — e.g. penguin, octopus, unicorn)
- 3 showpiece themes (true-black OLED, aurora, terracotta — all in code)
- 4–5 alternate app icons (highest perceived value per effort:
  `setAlternateIconName` + recolors of the existing icon)
- A small heart badge in Pet Corner + a thank-you line in About. Identity, not function.

**Price path:** $2.99 while the app is $4.99; move to $3.99 when the app hits
$6.99 (an IAP near the app's own price reads as nickel-and-diming). Expect 2–5%
of buyers to purchase — beer money in absolute terms, but it compounds forever,
builds the StoreKit plumbing for everything later, and gives your happiest users
the "shut up and take my money" outlet.

**StoreKit 2 notes (fits the no-server promise exactly):**
- One non-consumable; `Transaction.currentEntitlements` verifies on-device and
  works offline — airplane-mode users keep their pack. (~60 lines, no
  dependencies, no RevenueCat needed at this scale.)
- Start the `Transaction.updates` listener at app launch, not lazily.
- **Restore Purchases** button required (App Review 3.1.1) — bottom of the shelf.
- Use a StoreKit Configuration file for simulator testing; `ProductView` (iOS 17)
  renders Apple's own purchase UI so the shelf feels like a system surface.
- Privacy label stays "Data Not Collected" — StoreKit is Apple's commerce
  processing, not developer data collection. Note it in review notes.

**Presentation rules (anti-paywall):**
- A third "Supporter Shelf" section at the bottom of the existing Rewards list +
  one static row in Pet Corner. Nowhere else. No launch interstitials, badges,
  timers, SALE styling, or notification mentions — ever.
- The "next unlock" teaser in Pet Corner stays points-only. Never mix the lanes.
- Locked supporter items use the same visual grammar as locked earnable items,
  with a price where "Unlocks at N points" would be.
- The single highest-leverage line in this report, in the section footer, both
  languages: **"The app is complete without this."**

---

## 3. Tip jar ("buy the companion a treat")

- Honest numbers from public indie postmortems (Overcast's patronage decay,
  PCalc, et al.): 0.2–1% of active users tip, once, small — lower still in paid
  apps. Expect tens of dollars a month. It pays the $99 developer fee.
- Worth ~2 hours because §2 built the plumbing: three consumables — "Buy
  [active companion name] a treat" $1.99, "Snack basket" $4.99, "Feast" $9.99.
  On purchase: a one-off eating/celebration animation and a thank-you line.
- **Hard rule:** treats must not touch mood, points, streaks, or any state —
  the mood stays computed from real completions or you've built
  pay-for-progress with extra steps. The animation IS the product.
- Placement: Pet Corner only, below the "Real pet at home?" card. Never in
  Settings (worst-converting placement per every indie account), never prompted.

---

## 4. v2.0 "Two Homes" sync subscription

**The strategic fork:** CloudKit costs the developer $0, so "Apple hosts it"
won't survive scrutiny as a subscription justification. The honest ones:
ongoing maintenance of genuinely hard two-calendar sync, and funding continued
development — say the second plainly. Alternative structure: a one-time
"Two Homes" unlock at $19.99 — maximally on-brand but caps upside; choose it
only if v2.0 is likely the last major release. **Recommended: subscription.**

- **$14.99/yr or $1.99/mo, per family, 14-day free trial on annual.** The
  corridor: OurFamilyWizard ~$144+/yr per parent, TalkingParents ~$120/yr,
  2houses ~$150/yr — against that, $9.99 vs $14.99 is invisible; anchor the
  pitch: "Two-household sync: $14.99 a year for the whole family — not $144
  per parent." Optionally launch at $9.99/yr and raise for new subscribers
  later (existing subscribers can be price-preserved in App Store Connect).
- **Per-family via CKShare:** the subscriber creates the share; the co-parent
  joins free via link — matching the sociology (one parent is always the
  app-enthusiast). The other household still buys the $4.99–6.99 app: every
  subscription sells one extra copy. Market it: "Your co-parent just needs the
  app — the subscription covers both homes."
- **Grandfathering promises, printed in the listing:** everything local today
  stays free-with-purchase forever; sync is additive; **lapse = pause, never
  loss** (local SwiftData stays source of truth; a lapsed sub just stops
  pushing/pulling). Make that a tested code path — for custody data, a lapse
  that locked anything would be the ultimate betrayal.
- **StoreKit 2 essentials:** one subscription group, annual (highlighted) +
  monthly; `SubscriptionStoreView(groupID:)` is the entire paywall (a day, not
  weeks, and Apple-native); `Transaction.currentEntitlements` gates offline;
  enable **Billing Grace Period** (free churn recovery, it's a checkbox);
  subscription **offer codes** (up to 150k/quarter — code `COPARENT`, 1 month
  free, to the same communities); **win-back offers** (iOS 18+, auto-surfaced
  by the App Store to lapsed subscribers, zero code). Still no server needed.
- The subscription should **NOT** be Family Shareable — CKShare is the
  cross-household mechanism; Family Sharing the sub adds nothing and
  complicates entitlements.

---

## 5. Pricing psychology

**The ladder (replaces "consider $5.99 later"):** price is a quality claim; the
number is a roadmap, with each step tied to shipping and gated on ratings ≥ 4.5:

- **$3.99** launch fortnight (dated, promo-text-announced) →
- **$4.99** steady state →
- **$5.99 with v1.1** (widgets + streak + Siri — feature-comparable to Streaks,
  the $5.99 ADA-winning incumbent) →
- **$6.99 with v1.2** (companion bond + handoff ritual + latest-OS surfaces —
  now clearly more app than anything at $5.99, and the custody moat carries the
  premium).

Comparables: Due $7.99, Streaks $5.99, Things 3 $9.99, Paprika $4.99 — vs the
subscriptions the audience is fleeing (Structured ~$30/yr, Finch ~$40/yr,
Fantastical ~$57/yr). In the $4–7 band demand is conversion-constrained, not
price-constrained; the ladder costs almost nothing and buys a marketing beat
per step. Release-notes line each time: "Price rises with today's update —
existing owners are unaffected, as always."

**Regional pricing:** set base $4.99 and manually override LatAm storefronts to
**55–70% of US** (Apple's auto-prices track FX, not purchasing power): Mexico
MX$69, Colombia ~COP 14,900, Chile ~CLP 2,900–3,500, Peru ~PEN 14.90;
Argentina lowest sensible tier (60%+ purchase taxes make it marketing, not
revenue). **Spain: do NOT discount** (wealthy EU storefront ≈ €4.99) — what
moves Spain is the natively-written es-ES listing and featuring nominations.
Localize metadata separately for **es-MX and es-ES** (different keyword
corpora). Apply the same override pass to IAP prices.

**Family Sharing: ON at launch, deliberately.** Separated co-parents almost
never share an Apple Family, so the feared giveaway barely exists; what it
actually shares is copies within one household (new partner, grandparent,
teen) — additional caretakers running the same routines, deepening lock-in
ahead of the sync sub. It's also an editorial-visible goodwill feature. Note:
effectively one-way once granted — enable knowingly at launch.

**Price-increase choreography:** raise the same day as a feature release,
stated in notes and promo text; never during a featuring window or press bump
(raise in the quiet week after); schedule feature first, price second; announce
honestly beforehand ("goes to $5.99 with next week's widget update"). Long-term
(v3+): **Due's Upgrade Pass** (pay once, a year of updates included, optional
~$5/yr pass gating only post-window features, core reminders never gated) is
the only proven way to add recurring revenue to a paid offline utility without
a ratings collapse — this app's constraints were practically written for it.

---

## 6. What NOT to do — documented ratings-killers

1. **Moving existing paid features behind a subscription** — Notability's 2021
   reversal-in-days, Fantastical 3's months of review-bombing, Ulysses 2017.
   v2.0's sub may gate ONLY the sync that never existed before.
2. **Selling consistency** — purchasable streak shields would convert the
   custody-immune streak (the moat mechanic) into a cynical one. Unbuyable in
   perpetuity, including inside the Supporter Pack.
3. **Migrating earned cosmetics to paid, or selling points** — Finch's goodwill
   exists because the free path never degraded. The two-lane rule is the defense.
4. **Launch-screen upsells / badge-nagging in a paid app** — the most common
   1-star phrase is "I already paid and it's begging me for money." The
   Supporter Shelf placement rules exist to make that sentence unwritable.
5. **Paywalling widgets or the watch app later** — everything local ships to
   everyone who paid, forever.
6. **Adding an analytics SDK "to measure the funnel"** — it falsifies the
   load-bearing "Data Not Collected" label (an active App Review enforcement
   area). App Store Connect Sales/Trends + StoreKit transaction data give
   purchase counts with zero collection.
7. **Fake urgency / phantom discounts** — post-EU-omnibus, misleading reference
   prices are a compliance risk, not just a taste one. The honest dated
   announcement achieves the effect legally.
8. **Marketing push notifications** — Guideline 4.5.4 requires opt-in, and any
   non-informational ping from a *reminder* app trains users to revoke
   notification permission, killing the core product. Never announce the pack,
   a sale, or the sub via notification.

---

## Priority order (ruthless)

1. **Pre-submission (zero code):** promo-code batch plan, three featuring
   nominations, $3.99→$4.99 schedule with honest promo text, Family Sharing ON,
   manual LatAm price overrides.
2. **v1.0.x (~half a day):** review-prompt predicate on the all-done banner +
   Settings rate/email links.
3. **v1.1 (~3–4 days StoreKit):** Supporter Pack + treat consumables in one
   effort; price to $5.99 with the release.
4. **v1.2:** price to $6.99; extend the earnable points ladder; OS-surface
   featuring nomination.
5. **v2.0:** Two Homes — $14.99/yr per family, annual-first, trial, grace
   period, `COPARENT` offer codes, win-back offers, lapse-means-pause tested.

Key implementation files: `Engine/AppSettings.swift` (entitlement flag +
supporter lanes), `Views/PetCornerView.swift` (Supporter Shelf + treats),
`Views/TodayView.swift` (review-prompt hook), `Views/SettingsView.swift`
(rate link + restore), `RoutineReminderApp.swift` (Transaction.updates listener).
