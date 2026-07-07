# 🪺 Nido — Shared Custody Calendar for iPhone

Nido is a simple, friendly iPhone app for separated parents to coordinate custody of their child:

- **Tap-to-assign calendar** — each parent has a color; tap any day to record who has your child.
- **Approval workflow** — once a day is assigned, changing it (in either direction) requires the other parent's approval. Proposals land in a Requests inbox with Approve / Decline buttons.
- **Repeating schedules** — apply common patterns in seconds: alternating weeks, 2-2-3 rotation, every other weekend, or a custom weekly split.
- **Notes on days** — "Dentist at 5pm", "swim bag packed" — visible to both parents.
- **Statistics** — days with each parent per month and per year, with percentages.
- **Push notifications** — get notified when the other parent proposes, approves, or declines a change.
- **Private by design** — data lives in the creator's private iCloud and is shared *only* with the co-parent via CloudKit sharing. No third-party servers, no accounts, no subscription.
- **Invitations by QR code or link** — the co-parent scans a QR code or taps a link to join.
- **English + Spanish**, following the iPhone's language automatically.

## Requirements

- A Mac with **Xcode 16 or newer** (free from the Mac App Store).
- Two iPhones running **iOS 17 or newer**, each signed into its own **iCloud account**.
- An **Apple ID** to sign the app. A free account works for personal installs (app must be re-installed every 7 days); a paid Apple Developer account ($99/year) removes that limit and enables TestFlight.

## Getting started (first build)

1. Open `Nido/Nido.xcodeproj` in Xcode.
2. Select the **Nido** target → **Signing & Capabilities**:
   - Choose your **Team** (add your Apple ID under Xcode ▸ Settings ▸ Accounts if needed).
   - Change the **Bundle Identifier** to something unique to you, e.g. `com.yourname.nido`.
     The iCloud container is derived automatically (`iCloud.<bundle id>`), so no other change is needed.
3. Connect your iPhone with a cable, select it as the run destination, and press **Run** (⌘R).
4. On the phone, trust the developer certificate if prompted (Settings ▸ General ▸ VPN & Device Management).
5. Repeat on the co-parent's iPhone (same steps, same Mac — or use TestFlight, below).

> **Note on the first run:** the very first CloudKit operations create the schema automatically in the *Development* environment. Both phones must run a build from the same Xcode/team for sharing to work during development.

## Installing on the co-parent's phone

Two options:

- **Cable + Xcode** (free): plug their iPhone into your Mac and Run the app onto it, exactly like yours.
- **TestFlight** (needs the paid developer account): archive the app (Product ▸ Archive), upload to App Store Connect, and invite your co-parent by email in TestFlight. This is the most comfortable option — installs and updates happen over the air.

> **Important for TestFlight/App Store:** CloudKit has separate *Development* and *Production* environments. Before distributing via TestFlight, open the [CloudKit Console](https://icloud.developer.apple.com), select your container, and **Deploy Schema Changes to Production**. Do this after you've run the app once in development (so the record types exist).

## Using the app

1. **Parent 1** opens Nido → *Set up a new calendar* → enters their name, the child's name, and picks a color.
2. Nido shows an **invitation QR code**. Parent 2 installs Nido, opens *I have an invitation*, and scans the code (or taps the link sent by Messages/email — or pastes it).
3. Parent 2 enters their name and color. Both calendars are now live and in sync.
4. Tap any **unassigned** day to record who has the child — or use the ✨ wand button to apply a repeating schedule.
5. To change an **assigned** day, tap it and propose the change; the other parent approves or declines it from the Requests tab. Nothing changes hands without both of you agreeing.

## Project layout

```
Nido/
├── Nido.xcodeproj          Xcode project (iOS 17+, SwiftUI)
├── Config/                 Info.plist + entitlements (CloudKit, push, background)
└── Nido/
    ├── App/                App entry, delegates (push + share acceptance), root view
    ├── Models/             Domain models, date helpers, schedule patterns
    ├── Sync/               CloudKit service + FamilyStore (app state)
    ├── Theme/              Colors, reusable UI components
    ├── Views/              Onboarding, Calendar, Requests, Stats, Settings
    └── Resources/          Assets + bilingual string catalog (en/es)
```

## Privacy & security

- All data is stored in the **calendar creator's private iCloud database** inside a dedicated record zone shared with exactly one participant.
- The invitation link is the only way in; treat it like a house key and send it directly to your co-parent.
- Apple's CloudKit handles authentication (iCloud accounts), encryption in transit, and at rest.
- The app collects **zero analytics** and talks to no servers other than iCloud.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "iCloud needed" alert | Sign into iCloud in the iPhone Settings app and reopen Nido. |
| Invitation link does nothing on the co-parent's phone | Make sure Nido is installed *first*, then tap the link. Or use the in-app *Scan QR code* / paste-link option. |
| Changes don't appear on the other phone | Pull down the calendar to refresh. Push can take a moment; foreground refresh always fetches. |
| Notifications don't arrive | Notifications require accepting the permission prompt and a build with the push entitlement (device, not simulator). |
| Building for TestFlight works but the app can't see data | Deploy the CloudKit schema to Production in the CloudKit Console (see above). |
