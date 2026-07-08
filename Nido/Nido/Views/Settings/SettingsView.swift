import SwiftUI

struct SettingsView: View {
    @Environment(FamilyStore.self) private var store

    @State private var myName = ""
    @State private var myColor = Palette.defaultA
    @State private var loaded = false
    @State private var isSavingProfile = false
    @State private var showInvite = false
    @State private var confirmLeave = false
    @State private var confirmRemoveCoParent = false
    @State private var isRemovingCoParent = false
    @State private var showAddMember = false
    @State private var memberToDelete: Member?
    @State private var memberNames: [String: String] = [:]

    private var hasProfileChanges: Bool {
        guard let family = store.family else { return false }
        return myName != family.name(of: store.myRole)
            || myColor != family.colorHex(of: store.myRole)
    }

    var body: some View {
        NavigationStack {
            List {
                profileSection
                membersSection
                coParentSection
                syncSection
                dangerSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("Settings"))
            .onAppear { loadFromStore() }
            .onChange(of: store.family) { _, _ in
                // Refresh the form from a sync only when the user isn't
                // mid-edit, so their typing is never discarded.
                if !hasProfileChanges { loadFromStore(force: true) }
            }
            .onChange(of: store.members) { _, _ in syncMemberNames() }
            .sheet(isPresented: $showInvite) {
                NavigationStack {
                    InviteView(isOnboarding: false)
                }
            }
            .sheet(isPresented: $showAddMember) {
                AddMemberSheet()
                    .presentationDetents([.medium])
            }
            .confirmationDialog(
                store.myRole == .parentA
                    ? Text("Delete this shared calendar?")
                    : Text("Leave this shared calendar?"),
                isPresented: $confirmLeave,
                titleVisibility: .visible
            ) {
                Button(
                    store.myRole == .parentA ? String(localized: "Delete for both of us") : String(localized: "Leave calendar"),
                    role: .destructive
                ) {
                    Task { await store.leaveFamily() }
                }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text(store.myRole == .parentA
                     ? String(localized: "This permanently deletes the calendar, requests and notes for both parents.")
                     : String(localized: "You'll lose access to the shared calendar. To join again later, \(store.otherName) will need to remove you in their Settings and send a new invitation."))
            }
            .confirmationDialog(
                Text("Remove \(store.otherName) from the calendar?"),
                isPresented: $confirmRemoveCoParent,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Remove co-parent"), role: .destructive) {
                    Task {
                        isRemovingCoParent = true
                        await store.removeCoParent()
                        isRemovingCoParent = false
                    }
                }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text("They lose access immediately and the old invitation link stops working. The calendar and its history stay, and you can adjust all days freely until someone joins again.")
            }
            .confirmationDialog(
                Text("Remove \(memberToDelete?.name ?? "") from Nido?"),
                isPresented: Binding(
                    get: { memberToDelete != nil },
                    set: { if !$0 { memberToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(String(localized: "Remove and delete their days"), role: .destructive) {
                    if let member = memberToDelete {
                        Task { await store.deleteMember(member.id) }
                    }
                    memberToDelete = nil
                }
                Button("Keep it", role: .cancel) { memberToDelete = nil }
            } message: {
                Text("This deletes their whole calendar, notes and pending requests for both parents. It can't be undone.")
            }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            HStack {
                Text("Your name")
                Spacer()
                TextField("Name", text: $myName)
                    .multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Your color")
                ColorSwatchPicker(
                    selection: $myColor,
                    disabledHex: store.family?.colorHex(of: store.otherRole)
                )
            }
            if hasProfileChanges {
                Button {
                    Task {
                        isSavingProfile = true
                        await store.updateProfile(
                            myName: myName.trimmingCharacters(in: .whitespaces),
                            myColorHex: myColor
                        )
                        isSavingProfile = false
                    }
                } label: {
                    if isSavingProfile {
                        ProgressView()
                    } else {
                        Text("Save changes").bold()
                    }
                }
                .disabled(isSavingProfile || myName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("You")
        }
    }

    private var membersSection: some View {
        Section {
            ForEach(store.members) { member in
                HStack(spacing: 10) {
                    Image(systemName: member.symbolName)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 22)
                    TextField(
                        "Name",
                        text: Binding(
                            get: { memberNames[member.id] ?? member.name },
                            set: { memberNames[member.id] = $0 }
                        )
                    )
                    .onSubmit {
                        Task { await store.renameMember(member.id, to: memberNames[member.id] ?? member.name) }
                    }
                    Spacer()
                    if store.members.count > 1 {
                        Button {
                            memberToDelete = member
                        } label: {
                            Image(systemName: "trash")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("Remove \(member.name) from Nido?"))
                    }
                }
            }
            if store.members.count < Member.maxCount {
                Button {
                    showAddMember = true
                } label: {
                    Label("Add a child or pet", systemImage: "plus.circle.fill")
                }
            }
        } header: {
            Text("Children & pets")
        } footer: {
            Text("Each child or pet has their own custody calendar — schedules can differ between them.")
        }
    }

    private var coParentSection: some View {
        Section {
            if let family = store.family {
                if family.partnerHasJoined {
                    HStack(spacing: 10) {
                        ParentDot(colorHex: family.colorHex(of: store.otherRole), size: 12)
                        Text(family.name(of: store.otherRole))
                        Spacer()
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .labelStyle(.titleAndIcon)
                    }
                    if store.myRole == .parentA {
                        Button(role: .destructive) {
                            confirmRemoveCoParent = true
                        } label: {
                            if isRemovingCoParent {
                                ProgressView()
                            } else {
                                Text("Remove co-parent…")
                            }
                        }
                        .disabled(isRemovingCoParent)
                    }
                } else if store.myRole == .parentA {
                    Button {
                        showInvite = true
                    } label: {
                        Label("Show invitation", systemImage: "qrcode")
                    }
                    Text("Your co-parent hasn't joined yet. Send them the invitation so you can plan together.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Co-parent")
        }
    }

    private var syncSection: some View {
        Section {
            HStack {
                Text("Last synced")
                Spacer()
                if let syncedAt = store.lastSyncedAt {
                    Text(syncedAt.formatted(.relative(presentation: .named)))
                        .foregroundStyle(.secondary)
                } else {
                    Text(verbatim: "—").foregroundStyle(.secondary)
                }
            }
            Button {
                Task { await store.refresh() }
            } label: {
                if store.isSyncing {
                    HStack {
                        Text("Syncing…")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Text("Sync now")
                }
            }
            .disabled(store.isSyncing)
        } header: {
            Text("iCloud sync")
        } footer: {
            Text("Everything is stored in your private iCloud and shared only between the two of you. Notifications arrive automatically when something changes.")
        }
    }

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                confirmLeave = true
            } label: {
                Text(store.myRole == .parentA ? "Delete shared calendar" : "Leave shared calendar")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Nido — made for families who plan together. 🪺")
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private func loadFromStore(force: Bool = false) {
        guard let family = store.family, force || !loaded else { return }
        loaded = true
        myName = family.name(of: store.myRole)
        myColor = family.colorHex(of: store.myRole)
        syncMemberNames()
    }

    private func syncMemberNames() {
        for member in store.members {
            memberNames[member.id] = member.name
        }
        memberNames = memberNames.filter { id, _ in store.members.contains { $0.id == id } }
    }
}

// MARK: - Add member sheet

private struct AddMemberSheet: View {
    @Environment(FamilyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: Member.Kind = .child
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Luna", text: $name)
                        .padding(14)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Who are they?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Who are they?", selection: $kind) {
                        Label("Child", systemImage: "heart.fill").tag(Member.Kind.child)
                        Label("Pet", systemImage: "pawprint.fill").tag(Member.Kind.pet)
                    }
                    .pickerStyle(.segmented)
                }

                Text("They get their own custody calendar with the same colors and approval rules.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    Task {
                        isSaving = true
                        let added = await store.addMember(name: name, kind: kind)
                        isSaving = false
                        if added {
                            store.selectedMemberID = store.members.last?.id
                            dismiss()
                        }
                    }
                } label: {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Add to the family")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
            .background(Theme.background)
            .navigationTitle(Text("Add a child or pet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
