import SwiftUI

/// Sheet shown when tapping a calendar day: assign it, propose a change,
/// or attach a note.
struct DayDetailSheet: View {
    @Environment(FamilyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let dayKey: String

    @State private var noteText = ""
    @State private var noteLoaded = false
    @State private var isProposing = false
    @State private var proposalMessage = ""
    @State private var isWorking = false

    private var owner: ParentRole? { store.assignments[dayKey] }

    private var pendingChange: (request: ChangeRequest, change: DayChange)? {
        for request in store.requests where request.isPending {
            if let change = request.changes.first(where: { $0.dateKey == dayKey }) {
                return (request, change)
            }
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let pending = pendingChange {
                        pendingCard(pending)
                    } else if owner == nil {
                        assignSection
                    } else if isProposing {
                        proposeSection
                    } else {
                        actionSection
                    }

                    noteSection
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveNoteAndDismiss()
                    } label: {
                        Text("Done").bold()
                    }
                }
            }
        }
        .onAppear {
            if !noteLoaded {
                noteText = store.notes[dayKey] ?? ""
                noteLoaded = true
            }
        }
        .interactiveDismissDisabled(false)
        .onDisappear {
            Task { await store.setNote(noteText, for: dayKey) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(Day.longLabel(for: dayKey))
                .font(.title3.bold())

            if let owner, let family = store.family {
                HStack(spacing: 8) {
                    ParentDot(colorHex: family.colorHex(of: owner), size: 12)
                    Text("\(family.childName) is with \(family.name(of: owner))")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Color(hex: family.colorHex(of: owner)).opacity(0.15),
                    in: Capsule()
                )
            } else {
                Text("No parent assigned yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Pending request info

    private func pendingCard(_ pending: (request: ChangeRequest, change: DayChange)) -> some View {
        let requesterName = store.family?.name(of: pending.request.requester) ?? ""
        let newOwnerName = store.family?.name(of: pending.change.newOwner) ?? ""
        return VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Awaiting approval")
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.orange)
            }
            Text("\(requesterName) proposed that this day goes to \(newOwnerName). You can respond in the Requests tab.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    // MARK: - Unassigned: direct assignment

    private var assignSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let family = store.family {
                Text("Who has \(family.childName) this day?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    assignButton(for: .parentA, family: family)
                    assignButton(for: .parentB, family: family)
                }
            }
        }
    }

    private func assignButton(for role: ParentRole, family: Family) -> some View {
        Button {
            Task {
                isWorking = true
                await store.assignDay(dayKey, to: role)
                isWorking = false
                saveNoteAndDismiss()
            }
        } label: {
            VStack(spacing: 6) {
                ParentDot(colorHex: family.colorHex(of: role), size: 18)
                Text(family.name(of: role))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Color(hex: family.colorHex(of: role)).opacity(0.15),
                in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            )
        }
        .disabled(isWorking)
    }

    // MARK: - Assigned: propose a change

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let owner, let family = store.family {
                Button {
                    withAnimation { isProposing = true }
                } label: {
                    Label(
                        owner == store.myRole
                            ? String(localized: "Give this day to \(family.name(of: owner.other))")
                            : String(localized: "Ask to have this day"),
                        systemImage: "arrow.left.arrow.right"
                    )
                }
                .buttonStyle(SecondaryButtonStyle())

                Text("Changes to assigned days need \(store.otherName)'s approval.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var proposeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let owner, let family = store.family {
                let newOwner = owner.other
                Text("Propose: this day goes to \(family.name(of: newOwner))")
                    .font(.subheadline.weight(.semibold))

                TextField("Add a message (optional)", text: $proposalMessage, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

                Button {
                    Task {
                        isWorking = true
                        let sent = await store.submitRequest(
                            changes: [DayChange(dateKey: dayKey, newOwner: newOwner)],
                            message: proposalMessage
                        )
                        isWorking = false
                        if sent { saveNoteAndDismiss() }
                    }
                } label: {
                    if isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text("Send to \(store.otherName) for approval")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isWorking)

                Button {
                    withAnimation { isProposing = false }
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
    }

    // MARK: - Note

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note for this day")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("e.g. Dentist at 5pm, swim bag packed…", text: $noteText, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            Text("Notes are visible to both parents.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private func saveNoteAndDismiss() {
        let text = noteText
        Task { await store.setNote(text, for: dayKey) }
        dismiss()
    }
}
