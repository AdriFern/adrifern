import SwiftUI

/// Ask for days in plain words — on-device AI (Apple Intelligence)
/// turns "I need the second weekend of August" into concrete days,
/// the user reviews them, and the normal consent rules take over:
/// the AI only drafts, it never sends or changes anything.
struct NLProposalSheet: View {
    @Environment(FamilyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let member: Member

    private var ctx: FamilyStore.MemberContext? { store.context(member.id) }
    private var otherName: String { ctx?.otherName ?? String(localized: "Co-parent") }

    @State private var request = ""
    @State private var draftedDays: [NidoIntelligence.DraftedDay]?
    @State private var isDrafting = false
    @State private var draftFailed = false
    @State private var isApplying = false
    @State private var outcomeSummary: OutcomeSummary?
    @FocusState private var editorFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 7) {
                        Image(systemName: member.symbolName)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                        Text("Schedule for \(member.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("What do you need?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        TextField(
                            "e.g. I need the second weekend of August, and I offer the last weekend of July in return.",
                            text: $request,
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                        .focused($editorFocused)
                        .padding(14)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                        Text("Understood on this device by Apple Intelligence — nothing leaves your iPhone.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Button {
                        draftDays()
                    } label: {
                        if isDrafting {
                            ProgressView()
                        } else {
                            Label("Draft the days", systemImage: "wand.and.stars")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(isDrafting || request.trimmingCharacters(in: .whitespaces).isEmpty)

                    if draftFailed {
                        Text("That couldn't be turned into calendar days. Try naming the days more concretely — e.g. “the weekend of August 9”.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let days = draftedDays, let family = ctx?.family, let myRole = ctx?.myRole {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Check the days before sending")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(days, id: \.dateKey) { day in
                                let role = day.withMe ? myRole : myRole.other
                                HStack(spacing: 8) {
                                    Text(Day.shortLabel(for: day.dateKey))
                                        .font(.subheadline)
                                    Spacer()
                                    ParentDot(colorHex: family.colorHex(of: role), size: 10)
                                    Text(family.name(of: role))
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(16)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))

                        Text(ctx?.partnerJoined == true
                             ? String(localized: "The days go to \(otherName) as one proposal — nothing changes until they approve it.")
                             : String(localized: "You're not connected yet, so the days apply right away."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            applyDraft(days)
                        } label: {
                            if isApplying {
                                ProgressView().tint(.white)
                            } else {
                                Text(ctx?.partnerJoined == true
                                     ? String(localized: "Send for approval")
                                     : String(localized: "Apply days"))
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isApplying)
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle(Text("Ask in words"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert(item: $outcomeSummary) { summary in
                Alert(
                    title: Text(summary.title),
                    message: Text(summary.text),
                    dismissButton: .default(Text("OK")) { dismiss() }
                )
            }
            .alert(item: storeAlertBinding) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var storeAlertBinding: Binding<FamilyStore.AppAlert?> {
        @Bindable var store = store
        return $store.alert
    }

    private struct OutcomeSummary: Identifiable {
        let id = UUID()
        let title: String
        let text: String
    }

    private func draftDays() {
        editorFocused = false
        Task {
            isDrafting = true
            draftFailed = false
            draftedDays = nil
            let days = await NidoIntelligence.draftProposalDays(from: request)
            isDrafting = false
            if let days {
                draftedDays = days
            } else {
                draftFailed = true
            }
        }
    }

    private func applyDraft(_ days: [NidoIntelligence.DraftedDay]) {
        guard let myRole = ctx?.myRole else { return }
        var proposal: [String: ParentRole] = [:]
        for day in days {
            proposal[day.dateKey] = day.withMe ? myRole : myRole.other
        }
        Task {
            isApplying = true
            let outcome = await store.applyPattern(member: member.id, proposal: proposal)
            isApplying = false
            guard let outcome else { return }

            var parts: [String] = []
            let title: String
            if outcome.sentForApproval > 0 {
                title = String(localized: "Proposal sent")
                parts.append(String(localized: "The schedule was sent to \(otherName) as one proposal covering \(outcome.sentForApproval) days. It will apply once they approve it."))
            } else if outcome.appliedDirectly > 0 {
                title = String(localized: "Schedule applied")
                parts.append(String(localized: "\(outcome.appliedDirectly) days were filled in."))
            } else {
                title = String(localized: "Nothing to change")
                parts.append(String(localized: "Everything already matched this schedule — nothing to change."))
            }
            if outcome.skippedPending > 0 {
                parts.append(String(localized: "\(outcome.skippedPending) days were skipped because they're part of a pending request."))
            }
            outcomeSummary = OutcomeSummary(title: title, text: parts.joined(separator: " "))
        }
    }
}
