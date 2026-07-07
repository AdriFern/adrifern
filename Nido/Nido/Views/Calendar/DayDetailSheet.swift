import SwiftUI

/// Sheet shown when tapping a calendar day: assign it, propose a change,
/// respond to a pending request, or attach a note.
struct DayDetailSheet: View {
    @Environment(FamilyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let dayKey: String

    @State private var noteText = ""
    @State private var noteLoaded = false
    @State private var proposeTarget: ParentRole?
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
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if let pending = pendingChange {
                        pendingCard(pending)
                    } else if proposeTarget != nil {
                        proposeSection
                    } else {
                        whoSection
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
            // Errors must be able to present while this sheet is open;
            // the root-level alert can't appear underneath a sheet.
            .alert(item: $store.alert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            if !noteLoaded {
                noteText = store.notes[dayKey] ?? ""
                noteLoaded = true
            }
        }
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

    // MARK: - Pending request info + inline response

    private func pendingCard(_ pending: (request: ChangeRequest, change: DayChange)) -> some View {
        let isMine = pending.request.requester == store.myRole
        let requesterName = store.family?.name(of: pending.request.requester) ?? ""
        let newOwnerName = store.family?.name(of: pending.change.newOwner) ?? ""
        return VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Awaiting approval")
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.orange)
            }

            if isMine {
                Text("You proposed that this day goes to \(newOwnerName). \(store.otherName) hasn't responded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(role: .destructive) {
                    act {
                        await store.cancel(pending.request)
                        saveNoteAndDismiss()
                    }
                } label: {
                    Text("Cancel request")
                        .font(.subheadline.weight(.semibold))
                }
                .disabled(isWorking)
            } else {
                Text("\(requesterName) proposed that this day goes to \(newOwnerName).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if pending.request.changes.count > 1 {
                    Text("This is part of a proposal covering \(pending.request.changes.count) days — you approve or decline them together.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 10) {
                    Button {
                        act {
                            await store.approve(pending.request)
                            saveNoteAndDismiss()
                        }
                    } label: {
                        if isWorking {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label("Approve", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        act {
                            await store.decline(pending.request)
                            saveNoteAndDismiss()
                        }
                    } label: {
                        Label("Decline", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .disabled(isWorking)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    // MARK: - Who has the day (direct set, or hand-off into a proposal)

    private var whoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let family = store.family {
                Text("Who has \(family.childName) this day?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    assignButton(for: .parentA, family: family)
                    assignButton(for: .parentB, family: family)
                }
                if owner != nil, store.canEditDirectly(dayKey, settingTo: nil) {
                    Button {
                        act {
                            await store.setDayDirectly(dayKey, to: nil)
                            saveNoteAndDismiss()
                        }
                    } label: {
                        Text("Leave unassigned")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isWorking)
                }
                Text(whoFootnote(family: family))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func whoFootnote(family: Family) -> String {
        if !family.partnerHasJoined {
            return String(localized: "Until your co-parent joins, you can adjust days freely.")
        }
        if owner == nil {
            return String(localized: "Unassigned days can be filled in by either parent.")
        }
        if store.canEditDirectly(dayKey, settingTo: nil) {
            return String(localized: "You can clear this day, but giving it to \(store.otherName) needs their approval.")
        }
        return String(localized: "Changes to assigned days need \(store.otherName)'s approval.")
    }

    /// Tapping a parent either records the day directly (when allowed) or
    /// opens the proposal flow for the other parent's approval.
    private func assignButton(for role: ParentRole, family: Family) -> some View {
        let isCurrent = owner == role
        let isDirect = store.canEditDirectly(dayKey, settingTo: role)
        return Button {
            if isDirect {
                act {
                    await store.setDayDirectly(dayKey, to: role)
                    saveNoteAndDismiss()
                }
            } else {
                withAnimation { proposeTarget = role }
            }
        } label: {
            VStack(spacing: 6) {
                ParentDot(colorHex: family.colorHex(of: role), size: 18)
                Text(family.name(of: role))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !isCurrent && !isDirect {
                    Label("Needs approval", systemImage: "person.2")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Color(hex: family.colorHex(of: role)).opacity(0.15))
                    .overlay {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                                .strokeBorder(Color(hex: family.colorHex(of: role)), lineWidth: 2)
                        }
                    }
            )
        }
        .disabled(isWorking || isCurrent)
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }

    // MARK: - Proposal flow

    private var proposeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let target = proposeTarget, let family = store.family {
                Text("Propose: this day goes to \(family.name(of: target))")
                    .font(.subheadline.weight(.semibold))

                TextField("Add a message (optional)", text: $proposalMessage, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

                Button {
                    Task {
                        isWorking = true
                        let sent = await store.submitRequest(
                            changes: [DayChange(dateKey: dayKey, newOwner: target, oldOwner: owner)],
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
                    withAnimation { proposeTarget = nil }
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

    // MARK: - Helpers

    private func act(_ operation: @escaping () async -> Void) {
        Task {
            isWorking = true
            await operation()
            isWorking = false
        }
    }

    private func saveNoteAndDismiss() {
        let text = noteText
        Task { await store.setNote(text, for: dayKey) }
        dismiss()
    }
}
