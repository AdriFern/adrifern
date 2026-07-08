# 🪺 Nido — Shared Custody Calendar for iPhone

Nido is a simple, friendly iPhone app for separated parents to coordinate custody of their children — and pets:

- **Multiple families** — one person can have custody arrangements with **different exes** from the same app. Each family (one co-parent + the kids/pets you share with them) lives in its own private iCloud zone with its own invitation: families never see each other's schedules, members, or even that the others exist. Add another family anytime in Settings; requests always route to the right co-parent.
- **Multiple children & pets** — each family member (up to 8 per family) has their own independent custody calendar (schedules can differ per child or pet). Switch between them with one tap; add, rename or remove members in Settings. Removing a member permanently deletes their whole calendar and cancels their pending requests — both parents of that family can do it, and the other parent is always notified.

- **Tap-to-assign calendar** — each parent has a color; tap any unassigned day to record who has your child.
- **Approval workflow** — moving a day to the other parent, or changing a day they recorded or that was agreed through a request, requires their approval. Proposals land in a Requests inbox with Approve / Decline buttons (or respond right on the day). Days you recorded for yourself stay yours to clear.
- **Repeating schedules** — apply common patterns in seconds: alternating weeks, 2-2-3 rotation, every other weekend, or a custom weekly split. Once both parents are connected, a bulk schedule always goes to the other parent as one all-or-nothing proposal.
- **Notes on days** — "Dentist at 5pm", "swim bag packed" — visible to both parents.
- **Statistics** — days with each parent per month and per year, with percentages.
- **Notifications** — a push arrives when the calendar changes, plus detailed alerts ("María proposes a change for Sat, Jul 12") generated on refresh. iOS may delay pushes for force-quit apps; opening the app always syncs.
- **Private by design** — data lives in the creator's private iCloud and is shared via CloudKit sharing. Once your co-parent joins, the invitation link is closed at the iCloud level (on the creator's next sync — usually within moments) so nobody else can use it. Until then, treat it like a house key and send it only to your co-parent. No third-party servers, no accounts, no subscription.
- **Invitations by QR code or link** — the co-parent scans a QR code or taps a link to join.
- **Reinstall-proof** — "Restore an existing calendar" reconnects either parent after a new phone or reinstall.
- **English + Spanish**, following the iPhone's language automatically.

## Requirements

- A Mac with **Xcode 16 or newer** (free from the Mac App Store).
- Two iPhones running **iOS 17 or newer**, each signed into its own **iCloud account**.
- A **paid Apple Developer account** ($99/year). Nido uses CloudKit and push notifications, which Apple does not enable for free "Personal Team" signing. The paid account also gives you TestFlight, the easiest way to install on the co-parent's phone.
- Both parents are assumed to live in the same time zone (days are counted in each device's local calendar).

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

1. **Parent 1** opens Nido → *Set up a new calendar* → enters their name, the first child's (or pet's) name, and picks a color. More children and pets can be added anytime in Settings.
2. Nido shows an **invitation QR code**. Parent 2 installs Nido, opens *I have an invitation*, and scans the code (or taps the link sent by Messages/email — or pastes it).
3. Parent 2 enters their name and color. Both calendars are now live and in sync.
4. Tap any **unassigned** day to record who has the child — the other parent gets a heads-up notification. Use the ✨ Schedule button for repeating patterns: while you're solo they apply instantly; once your co-parent has joined, the whole schedule goes to them as **one proposal** and nothing changes until they approve it.
5. To move any assigned day **to the other parent** — or to change a day they recorded or that was agreed through a request — tap it and send the proposal; they approve or decline it from the Requests tab or right on the day. An *assigned* day never changes hands without approval; recording an *empty* day for the other parent is direct (they get a notification and can clear it with one tap). Days recorded for you stay yours to clear.

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

- All data is stored in the **calendar creator's private iCloud database**, one dedicated record zone per family, each shared through CloudKit with exactly that family's co-parent. Different families are isolated CloudKit zones and shares — iCloud only grants each co-parent access to their own family's zone, so no cross-visibility is possible.
- The invitation link is the only way in. Once your co-parent joins, the share's public permission is revoked on iCloud, so the link goes dead for everyone else; rejoining from the same iCloud account remains possible. Before the join happens, treat the link like a house key and send it directly to your co-parent only.
- The calendar creator can disconnect the co-parent at any time (Settings → Remove co-parent). Their access is revoked immediately, the old invitation link is permanently destroyed, and a fresh link is minted the next time the invitation screen is opened — the calendar and its history stay.
- Apple's CloudKit handles authentication (iCloud accounts), encryption in transit, and at rest.
- The app collects **zero analytics** and talks to no servers other than iCloud.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| "iCloud needed" alert | Sign into iCloud in the iPhone Settings app and reopen Nido. |
| Invitation link does nothing on the co-parent's phone | Make sure Nido is installed *first*, then tap the link. Or use the in-app *Scan QR code* / paste-link option. |
| Changes don't appear on the other phone | Pull down the calendar to refresh. Push can take a moment; foreground refresh always fetches. |
| Notifications don't arrive | Notifications require accepting the permission prompt and a build with the push entitlement (device, not simulator). iOS also throttles pushes to force-quit apps — reopening the app always catches up. |
| Reinstalled the app / new phone | On the welcome screen choose **Restore an existing calendar** — it finds your calendar (owned or shared) on the same iCloud account. |
| Co-parent left, or switched iCloud accounts, and can't rejoin | The calendar creator taps Settings → **Remove co-parent**, then sends a fresh invitation. |
| Building for TestFlight works but the app can't see data | Deploy the CloudKit schema to Production in the CloudKit Console (see above). |
