import SwiftUI

struct SettingsView: View {
    @Environment(FamilyStore.self) private var store

    @State private var showAddMember = false
    @State private var showAddFamily = false
    @State private var memberToDelete: Member?
    @State private var memberNames: [String: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                familiesSection
                membersSection
                syncSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("Settings"))
            .onAppear { syncMemberNames() }
            .onChange(of: store.members) { _, _ in syncMemberNames() }
            .sheet(isPresented: $showAddMember) {
                AddMemberSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showAddFamily) {
                AddFamilySheet()
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

    // MARK: - Families

    private var familiesSection: some View {
        Section {
            ForEach(store.familyRefs) { familyRef in
                NavigationLink {
                    FamilySettingsView(familyID: familyRef.id)
                } label: {
                    HStack(spacing: 10) {
                        if let family = store.family(familyRef.id) {
                            ParentDot(colorHex: family.colorHex(of: familyRef.role.other), size: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(family.partnerHasJoined || familyRef.role == .parentB
                                     ? String(localized: "With \(family.name(of: familyRef.role.other))")
                                     : String(localized: "Waiting for your co-parent"))
                                    .font(.subheadline.weight(.semibold))
                                Text(memberSummary(for: familyRef.id))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if store.family(familyRef.id)?.partnerHasJoined == true {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            if store.pendingJoinFamilyID != nil {
                NavigationLink {
                    JoinProfileView()
                } label: {
                    Label("Finish joining", systemImage: "person.crop.circle.badge.clock")
                        .foregroundStyle(Color.accentColor)
                }
            }
            Button {
                showAddFamily = true
            } label: {
                Label("Add another family (new co-parent)", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Families")
        } footer: {
            Text("Each family is a separate, private calendar with one co-parent. Families never see each other's schedules.")
        }
    }

    private func memberSummary(for familyID: String) -> String {
        store.membersOf(familyID).map(\.name).joined(separator: ", ")
    }

    // MARK: - Members

    private var membersSection: some View {
        Section {
            ForEach(store.members) { member in
                let draftName = memberNames[member.id] ?? member.name
                HStack(spacing: 10) {
                    // Tapping the icon flips child ↔ pet — no need to
                    // delete a calendar to fix a mis-tap.
                    Button {
                        Task {
                            await store.setMemberKind(member.id, to: member.kind == .child ? .pet : .child)
                        }
                    } label: {
                        Image(systemName: member.symbolName)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 22)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Switch between child and pet"))

                    VStack(alignment: .leading, spacing: 1) {
                        TextField(
                            "Name",
                            text: Binding(
                                get: { draftName },
                                set: { memberNames[member.id] = $0 }
                            )
                        )
                        .onSubmit {
                            Task { await store.renameMember(member.id, to: draftName) }
                        }
                        if store.familyRefs.count > 1, let ctx = store.context(member.id) {
                            Text("With \(ctx.otherName)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if draftName.trimmingCharacters(in: .whitespaces) != member.name,
                       !draftName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            Task { await store.renameMember(member.id, to: draftName) }
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("Save name"))
                    } else if canDelete(member) {
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
            Button {
                showAddMember = true
            } label: {
                Label("Add a child or pet", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Children & pets")
        } footer: {
            Text("Each child or pet has their own custody calendar — schedules can differ between them.")
        }
    }

    private func canDelete(_ member: Member) -> Bool {
        guard let familyID = store.familyID(ofMember: member.id) else { return false }
        return store.membersOf(familyID).count > 1
    }

    // MARK: - Sync / About

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

    private var aboutSection: some View {
        Section {
            NavigationLink {
                HelpView()
            } label: {
                Label {
                    Text("Help & FAQ")
                } icon: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Color.accentColor)
                }
            }
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

    private func syncMemberNames() {
        // Seed only missing entries so a remote sync never clobbers a
        // rename the user is typing right now.
        for member in store.members where memberNames[member.id] == nil {
            memberNames[member.id] = member.name
        }
        memberNames = memberNames.filter { id, _ in store.members.contains { $0.id == id } }
    }
}

// MARK: - Per-family settings

struct FamilySettingsView: View {
    @Environment(FamilyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let familyID: String

    @State private var myName = ""
    @State private var myColor = Palette.defaultA
    @State private var myWhatsApp = ""
    @State private var loaded = false
    @State private var isSavingProfile = false
    @State private var isSavingWhatsApp = false
    @State private var showInvite = false
    @State private var confirmLeave = false
    @State private var confirmRemoveCoParent = false
    @State private var isRemovingCoParent = false

    private var familyRef: FamilyRef? { store.ref(familyID) }
    private var family: Family? { store.family(familyID) }
    private var myRole: ParentRole { familyRef?.role ?? .parentA }
    private var otherName: String {
        family?.name(of: myRole.other) ?? String(localized: "Co-parent")
    }

    private var hasProfileChanges: Bool {
        guard let family else { return false }
        return myName != family.name(of: myRole) || myColor != family.colorHex(of: myRole)
    }

    /// Any in-progress edit (profile or WhatsApp) that a remote sync
    /// must not clobber by reloading the form.
    private var hasUnsavedEdits: Bool {
        guard let family else { return false }
        return hasProfileChanges
            || myWhatsApp.trimmingCharacters(in: .whitespaces) != family.whatsApp(of: myRole)
    }

    var body: some View {
        List {
            profileSection
            whatsAppSection
            coParentSection
            dangerSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Family"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromFamily() }
        .onChange(of: family) { _, _ in
            // Refresh the form from a sync only when the user isn't
            // mid-edit, so their typing is never discarded.
            if !hasUnsavedEdits { loadFromFamily(force: true) }
        }
        .sheet(isPresented: $showInvite) {
            NavigationStack {
                InviteView(familyID: familyID, isOnboarding: false)
            }
        }
        .confirmationDialog(
            myRole == .parentA
                ? Text("Delete this shared calendar?")
                : Text("Leave this shared calendar?"),
            isPresented: $confirmLeave,
            titleVisibility: .visible
        ) {
            Button(
                myRole == .parentA ? String(localized: "Delete for both of us") : String(localized: "Leave calendar"),
                role: .destructive
            ) {
                Task {
                    await store.leaveFamily(familyID)
                    dismiss()
                }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text(myRole == .parentA
                 ? String(localized: "This permanently deletes the calendar, requests and notes for both parents.")
                 : String(localized: "You'll lose access to the shared calendar. To join again later, \(otherName) will need to remove you in their Settings and send a new invitation."))
        }
        .confirmationDialog(
            Text("Remove \(otherName) from the calendar?"),
            isPresented: $confirmRemoveCoParent,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Remove co-parent"), role: .destructive) {
                Task {
                    isRemovingCoParent = true
                    await store.removeCoParent(familyID: familyID)
                    isRemovingCoParent = false
                }
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("They lose access immediately and the old invitation link stops working. The calendar and its history stay, and you can adjust all days freely until someone joins again.")
        }
    }

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
                    disabledHex: family?.colorHex(of: myRole.other)
                )
            }
            if hasProfileChanges {
                Button {
                    Task {
                        isSavingProfile = true
                        await store.updateProfile(
                            familyID: familyID,
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
            Text("You in this family")
        }
    }

    private var whatsAppSection: some View {
        Section {
            HStack {
                TextField("+34 600 123 456", text: $myWhatsApp)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                if myWhatsApp.trimmingCharacters(in: .whitespaces) != (family?.whatsApp(of: myRole) ?? "") {
                    Button {
                        Task {
                            isSavingWhatsApp = true
                            await store.updateMyWhatsApp(familyID: familyID, number: myWhatsApp)
                            isSavingWhatsApp = false
                        }
                    } label: {
                        if isSavingWhatsApp {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .disabled(isSavingWhatsApp)
                    .accessibilityLabel(Text("Save WhatsApp number"))
                }
            }
        } header: {
            Text("Your WhatsApp (optional)")
        } footer: {
            Text("Shared only with \(otherName), so their “Notify on WhatsApp” buttons open your chat directly. Include the country code. Leave empty to share nothing — the buttons then open WhatsApp's contact picker instead.")
        }
    }

    private var coParentSection: some View {
        Section {
            if let family {
                if family.partnerHasJoined {
                    HStack(spacing: 10) {
                        ParentDot(colorHex: family.colorHex(of: myRole.other), size: 12)
                        Text(family.name(of: myRole.other))
                        Spacer()
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .labelStyle(.titleAndIcon)
                    }
                    if myRole == .parentA {
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
                } else if myRole == .parentA {
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

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                confirmLeave = true
            } label: {
                Text(myRole == .parentA ? "Delete shared calendar" : "Leave shared calendar")
            }
        }
    }

    private func loadFromFamily(force: Bool = false) {
        guard let family, force || !loaded else { return }
        loaded = true
        myName = family.name(of: myRole)
        myColor = family.colorHex(of: myRole)
        myWhatsApp = family.whatsApp(of: myRole)
    }
}

// MARK: - Add member sheet

private struct AddMemberSheet: View {
    @Environment(FamilyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: Member.Kind = .child
    @State private var targetFamilyID: String?
    @State private var isSaving = false

    private var resolvedFamilyID: String? {
        targetFamilyID ?? store.familyRefs.first?.id
    }

    /// Label a family by its co-parent, or by its members while the
    /// co-parent hasn't joined (so two solo families stay distinguishable).
    private func familyLabel(_ familyRef: FamilyRef) -> String {
        guard let family = store.family(familyRef.id) else { return "…" }
        if family.partnerHasJoined || familyRef.role == .parentB {
            return family.name(of: familyRef.role.other)
        }
        return store.membersOf(familyRef.id).first?.name ?? String(localized: "Waiting for your co-parent")
    }

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

                if store.familyRefs.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Which family?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Which family?", selection: Binding(
                            get: { resolvedFamilyID ?? "" },
                            set: { targetFamilyID = $0 }
                        )) {
                            ForEach(store.familyRefs) { familyRef in
                                Text(familyLabel(familyRef))
                                    .tag(familyRef.id)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Text("They get their own custody calendar with the same colors and approval rules.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    Task {
                        guard let familyID = resolvedFamilyID else { return }
                        isSaving = true
                        let added = await store.addMember(familyID: familyID, name: name, kind: kind)
                        isSaving = false
                        if added {
                            store.selectedMemberID = store.membersOf(familyID).last?.id
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
                .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty || resolvedFamilyID == nil)
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

// MARK: - Add family sheet (a NEW co-parent relationship)

struct AddFamilySheet: View {
    @Environment(FamilyStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("A family is one co-parent plus the children or pets you share with them. Families are completely separate — the other family never sees anything.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)

                NavigationLink {
                    CreateFamilyView(isAdditional: true, onFinished: { dismiss() })
                } label: {
                    Text("Set up a new calendar")
                }
                .buttonStyle(PrimaryButtonStyle())

                NavigationLink {
                    JoinFamilyView()
                } label: {
                    Text("I have an invitation")
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()
            }
            .padding(24)
            .background(Theme.background)
            .navigationTitle(Text("Add another family"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
