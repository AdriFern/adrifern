import SwiftUI

struct SettingsView: View {
    @Environment(FamilyStore.self) private var store

    @State private var childName = ""
    @State private var myName = ""
    @State private var myColor = Palette.defaultA
    @State private var loaded = false
    @State private var isSavingProfile = false
    @State private var showInvite = false
    @State private var confirmLeave = false

    private var hasProfileChanges: Bool {
        guard let family = store.family else { return false }
        return childName != family.childName
            || myName != family.name(of: store.myRole)
            || myColor != family.colorHex(of: store.myRole)
    }

    var body: some View {
        NavigationStack {
            List {
                familySection
                coParentSection
                syncSection
                dangerSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("Settings"))
            .onAppear { loadFromFamily() }
            .onChange(of: store.family) { _, _ in
                // Refresh the form from a sync only when the user isn't
                // mid-edit, so their typing is never discarded.
                if !hasProfileChanges { loadFromFamily(force: true) }
            }
            .sheet(isPresented: $showInvite) {
                NavigationStack {
                    InviteView(isOnboarding: false)
                }
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
                     : String(localized: "You'll lose access to the shared calendar until you're invited again."))
            }
        }
    }

    // MARK: - Sections

    private var familySection: some View {
        Section {
            HStack {
                Text("Child")
                Spacer()
                TextField("Name", text: $childName)
                    .multilineTextAlignment(.trailing)
            }
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
                            childName: childName.trimmingCharacters(in: .whitespaces),
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
                .disabled(
                    isSavingProfile ||
                    childName.trimmingCharacters(in: .whitespaces).isEmpty ||
                    myName.trimmingCharacters(in: .whitespaces).isEmpty
                )
            }
        } header: {
            Text("Family")
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
                    Text("—").foregroundStyle(.secondary)
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

    private func loadFromFamily(force: Bool = false) {
        guard let family = store.family, force || !loaded else { return }
        loaded = true
        childName = family.childName
        myName = family.name(of: store.myRole)
        myColor = family.colorHex(of: store.myRole)
    }
}
