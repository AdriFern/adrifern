import SwiftUI

/// In-app manual: a simplified FAQ covering everything a user can do,
/// reachable from Settings. Questions expand in place; the list is
/// searchable so answers are quick to find mid-argument at handover time.
struct HelpView: View {
    @State private var search = ""

    var body: some View {
        List {
            ForEach(filteredSections) { section in
                Section {
                    ForEach(section.items) { item in
                        FAQRow(item: item)
                    }
                } header: {
                    Text(section.title)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Theme.background)
        .navigationTitle(Text("Help"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: Text("Search help"))
        .overlay {
            if filteredSections.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
    }

    private var filteredSections: [FAQSection] {
        let all = Self.sections()
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.compactMap { section in
            let hits = section.items.filter {
                $0.question.localizedCaseInsensitiveContains(query) ||
                $0.answer.localizedCaseInsensitiveContains(query)
            }
            return hits.isEmpty ? nil : FAQSection(title: section.title, items: hits)
        }
    }
}

// MARK: - Row

private struct FAQRow: View {
    let item: FAQItem
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            Text(item.answer)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .textSelection(.enabled)
        } label: {
            Text(item.question)
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 2)
        }
    }
}

// MARK: - Content

private struct FAQItem: Identifiable {
    let question: String
    let answer: String
    var id: String { question }
}

private struct FAQSection: Identifiable {
    let title: String
    let items: [FAQItem]
    var id: String { title }
}

private extension HelpView {
    /// Built on demand so the strings always follow the current language.
    static func sections() -> [FAQSection] {
        [
            FAQSection(title: String(localized: "Getting started"), items: [
                FAQItem(
                    question: String(localized: "How do I connect with my co-parent?"),
                    answer: String(localized: "Open Settings → Families, choose the family and tap “Show invitation”. Your co-parent installs Nido on their iPhone, then scans the QR code or taps the link you send them. As soon as they join, the link stops working for anyone else.")
                ),
                FAQItem(
                    question: String(localized: "The invitation link doesn't work on their phone."),
                    answer: String(localized: "Make sure Nido is installed before tapping the link. They can also open Nido, choose “I have an invitation”, and scan the QR code or paste the link. If someone already used the invitation, remove the co-parent in the family's settings — a fresh link is created automatically.")
                ),
                FAQItem(
                    question: String(localized: "I got a new phone or reinstalled the app."),
                    answer: String(localized: "On the welcome screen choose “Restore an existing calendar”. It finds every calendar you own or joined with the same iCloud account — nothing is lost.")
                ),
                FAQItem(
                    question: String(localized: "I received an invitation I don't want."),
                    answer: String(localized: "On the join screen tap “Don't join”. Nothing is shared with you, and you can still join later with a new invitation link.")
                ),
            ]),
            FAQSection(title: String(localized: "The calendar"), items: [
                FAQItem(
                    question: String(localized: "How do I record who has our child on a day?"),
                    answer: String(localized: "Tap any empty day and choose a parent. Empty days can be filled in by either of you — the other parent gets a notification, and a day recorded for them can be cleared by them with one tap. A day someone records for themselves only changes through a proposal.")
                ),
                FAQItem(
                    question: String(localized: "Why do some days say “Needs approval”?"),
                    answer: String(localized: "A day that's already assigned never changes hands without the other parent's consent. Tapping it prepares a proposal instead of changing anything — nothing moves until they approve.")
                ),
                FAQItem(
                    question: String(localized: "What does the small clock on a day mean?"),
                    answer: String(localized: "That day is part of a pending request. It stays locked until the request is approved, declined or cancelled.")
                ),
                FAQItem(
                    question: String(localized: "How do I clear a day back to unassigned?"),
                    answer: String(localized: "Tap the day and choose “Leave unassigned”. You can clear days that were recorded for you directly; days agreed through an approved request need a new proposal to change.")
                ),
                FAQItem(
                    question: String(localized: "How do notes on days work?"),
                    answer: String(localized: "Tap a day and write in the note field — “Dentist at 5pm”, “swim bag packed”. Notes are visible to both parents of that family, and a small dot marks days that have one.")
                ),
            ]),
            FAQSection(title: String(localized: "Requests"), items: [
                FAQItem(
                    question: String(localized: "How do I propose a schedule change?"),
                    answer: String(localized: "Tap the day and choose the parent it should go to. Add an optional message and send — your co-parent gets a notification and decides from their Requests tab or right on the day.")
                ),
                FAQItem(
                    question: String(localized: "How do I approve or decline a request?"),
                    answer: String(localized: "Open the Requests tab and use the Approve or Decline buttons, or tap the affected day itself. Approving applies every day in the proposal at once.")
                ),
                FAQItem(
                    question: String(localized: "Can I cancel a request I sent?"),
                    answer: String(localized: "Yes — open Requests and tap “Cancel request” under your pending proposal, any time before your co-parent responds.")
                ),
                FAQItem(
                    question: String(localized: "I approved a request but some days didn't change."),
                    answer: String(localized: "If a day changed after the proposal was sent, that day is skipped for safety and Nido tells you so. The remaining days apply normally.")
                ),
            ]),
            FAQSection(title: String(localized: "Repeating schedules"), items: [
                FAQItem(
                    question: String(localized: "How do I set up alternating weeks or a 2-2-3 rotation?"),
                    answer: String(localized: "Tap the ✨ Schedule button on the calendar, pick a pattern and who goes first, and check the preview. While you're on your own it applies instantly; once your co-parent has joined, the whole schedule goes to them as one all-or-nothing proposal.")
                ),
                FAQItem(
                    question: String(localized: "Can each child or pet have a different schedule?"),
                    answer: String(localized: "Yes. Every child and pet has a fully independent calendar — open theirs with the chips at the top and apply a different pattern to each.")
                ),
            ]),
            FAQSection(title: String(localized: "Children, pets & families"), items: [
                FAQItem(
                    question: String(localized: "How do I add another child or a pet?"),
                    answer: String(localized: "Settings → Children & pets → “Add a child or pet”. They get their own calendar with the same colors and approval rules; switch between calendars with the chips at the top.")
                ),
                FAQItem(
                    question: String(localized: "How do I rename or remove a child or pet?"),
                    answer: String(localized: "In Settings → Children & pets, edit the name in place, or tap the trash icon to remove them. Removing permanently deletes their whole calendar and notes and cancels their pending requests — the other parent is always notified.")
                ),
                FAQItem(
                    question: String(localized: "Can I manage custody with more than one ex?"),
                    answer: String(localized: "Yes. Settings → Families → “Add another family” creates a second, completely separate calendar with its own co-parent and its own invitation. Requests always show which co-parent they involve.")
                ),
                FAQItem(
                    question: String(localized: "What can one family see about the other?"),
                    answer: String(localized: "Nothing at all. Each family lives in its own private iCloud space — the other co-parent can't see its schedule, its members, or even that it exists.")
                ),
                FAQItem(
                    question: String(localized: "How do I disconnect my co-parent?"),
                    answer: String(localized: "Open Settings → Families → the family → “Remove co-parent…”. Their access ends immediately and the old invitation link is destroyed; a fresh link is created the next time you open the invitation screen. The calendar and its history stay.")
                ),
                FAQItem(
                    question: String(localized: "How do I leave a calendar I joined?"),
                    answer: String(localized: "Open Settings → Families → the family, and leave the shared calendar from there. You can rejoin later with a new invitation.")
                ),
            ]),
            FAQSection(title: String(localized: "Sync, notifications & privacy"), items: [
                FAQItem(
                    question: String(localized: "Changes aren't appearing on the other phone."),
                    answer: String(localized: "Pull down on the calendar to refresh, or use Settings → “Sync now”. Push updates can take a moment; opening the app always fetches the latest.")
                ),
                FAQItem(
                    question: String(localized: "I'm not getting notifications."),
                    answer: String(localized: "Check that notifications are allowed for Nido in the iPhone's Settings app. iOS may delay pushes when the app was force-quit — opening Nido always catches up on what happened.")
                ),
                FAQItem(
                    question: String(localized: "Where is our data stored? Is it private?"),
                    answer: String(localized: "In the calendar creator's private iCloud, shared through Apple's iCloud sharing with exactly one co-parent per family. No accounts, no third-party servers, zero analytics.")
                ),
                FAQItem(
                    question: String(localized: "The app says “iCloud needed”."),
                    answer: String(localized: "Sign into iCloud in the iPhone's Settings app, then reopen Nido. Each parent needs their own iCloud account.")
                ),
            ]),
        ]
    }
}
