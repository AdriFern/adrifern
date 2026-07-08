import SwiftUI

/// Inbox for schedule change proposals: approve/decline incoming ones,
/// cancel your own, and browse the history.
struct RequestsView: View {
    @Environment(FamilyStore.self) private var store

    var body: some View {
        NavigationStack {
            Group {
                if store.requests.isEmpty {
                    ContentUnavailableView(
                        "No requests yet",
                        systemImage: "arrow.left.arrow.right.circle",
                        description: Text("When either of you proposes a schedule change, it will show up here for the other to approve.")
                    )
                } else {
                    List {
                        if !store.pendingIncoming.isEmpty {
                            Section {
                                ForEach(store.pendingIncoming) { request in
                                    RequestRow(request: request, mode: .incoming)
                                }
                            } header: {
                                Text("For you to approve")
                            }
                        }

                        if !store.pendingOutgoing.isEmpty {
                            Section {
                                ForEach(store.pendingOutgoing) { request in
                                    RequestRow(request: request, mode: .outgoing)
                                }
                            } header: {
                                // Outgoing requests may target different
                                // co-parents when several families exist.
                                Text(outgoingHeader)
                            }
                        }

                        if !store.resolvedRequests.isEmpty {
                            Section {
                                ForEach(store.resolvedRequests.prefix(25)) { request in
                                    RequestRow(request: request, mode: .history)
                                }
                            } header: {
                                Text("History")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(Text("Requests"))
            .background(Theme.background)
            .refreshable {
                await store.refresh()
            }
        }
    }

    private var outgoingHeader: String {
        let names = Set(store.pendingOutgoing.map { store.otherPartyName(of: $0) })
        if names.count == 1, let only = names.first {
            return String(localized: "Waiting for \(only)")
        }
        return String(localized: "Waiting for approval")
    }
}

// MARK: - Row

struct RequestRow: View {
    enum Mode { case incoming, outgoing, history }

    @Environment(FamilyStore.self) private var store
    let request: ChangeRequest
    let mode: Mode

    @State private var expanded = false
    @State private var isWorking = false

    private var requesterName: String {
        store.requesterName(of: request)
    }

    private var family: Family? { store.family(request.familyID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(mode == .outgoing ? String(localized: "You proposed") : String(localized: "\(requesterName) proposes"))
                    .font(.subheadline.weight(.semibold))
                if let member = store.member(request.memberID) {
                    if store.members.count > 1 {
                        HStack(spacing: 4) {
                            Image(systemName: member.symbolName)
                                .font(.caption2)
                            Text(member.name)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                } else {
                    // History rows must stay attributable after a member
                    // is deleted, so they never read as the survivor's.
                    Text("Removed member")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
                Spacer()
                if mode == .history {
                    statusChip
                } else {
                    Text(request.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // With several families, spell out which co-parent this
            // involves — member names alone can repeat across families.
            if store.familyRefs.count > 1 {
                Text("With \(store.otherPartyName(of: request))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            changesList

            if request.kind == .pattern {
                Label {
                    Text("Repeating schedule proposal")
                        .font(.caption)
                } icon: {
                    Image(systemName: "wand.and.stars")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            } else if !request.message.isEmpty {
                Text("“\(request.message)”")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
            }

            if mode == .incoming {
                HStack(spacing: 10) {
                    Button {
                        act { await store.approve(request) }
                    } label: {
                        if isWorking {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Approve", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        act { await store.decline(request) }
                    } label: {
                        Label("Decline", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .disabled(isWorking)
                .padding(.top, 2)
            }

            if mode == .outgoing {
                Button(role: .destructive) {
                    act { await store.cancel(request) }
                } label: {
                    Text("Cancel request")
                        .font(.subheadline)
                }
                .disabled(isWorking)
            }
        }
        .padding(.vertical, 6)
    }

    private func act(_ operation: @escaping () async -> Void) {
        Task {
            isWorking = true
            await operation()
            isWorking = false
        }
    }

    // MARK: Pieces

    private var visibleChanges: [DayChange] {
        expanded ? request.changes : Array(request.changes.prefix(3))
    }

    private var changesList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(visibleChanges, id: \.self) { change in
                if let family = family {
                    // Long names (especially in Spanish) fall back to two lines.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            Text(Day.shortLabel(for: change.dateKey))
                                .font(.subheadline)
                            oldOwnerLabel(change: change, family: family)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            newOwnerLabel(change: change, family: family)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Day.shortLabel(for: change.dateKey))
                                .font(.subheadline)
                            HStack(spacing: 8) {
                                oldOwnerLabel(change: change, family: family)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                newOwnerLabel(change: change, family: family)
                            }
                        }
                    }
                }
            }
            if request.changes.count > 3 {
                Button {
                    withAnimation { expanded.toggle() }
                } label: {
                    Text(expanded ? String(localized: "Show less") : String(localized: "+\(request.changes.count - 3) more days"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func oldOwnerLabel(change: DayChange, family: Family) -> some View {
        Group {
            if let oldOwner = change.oldOwner {
                HStack(spacing: 4) {
                    ParentDot(colorHex: family.colorHex(of: oldOwner), size: 8)
                    Text(family.name(of: oldOwner))
                }
            } else {
                Text("Unassigned")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private func newOwnerLabel(change: DayChange, family: Family) -> some View {
        HStack(spacing: 4) {
            ParentDot(colorHex: family.colorHex(of: change.newOwner), size: 8)
            Text(family.name(of: change.newOwner))
        }
        .font(.subheadline)
    }

    private var statusChip: some View {
        Group {
            switch request.status {
            case .approved:
                Label("Approved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .declined:
                Label("Declined", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .cancelled:
                Label("Cancelled", systemImage: "minus.circle.fill")
                    .foregroundStyle(.secondary)
            case .pending:
                Label("Pending", systemImage: "clock.fill")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption.weight(.semibold))
        .labelStyle(.titleAndIcon)
    }
}
