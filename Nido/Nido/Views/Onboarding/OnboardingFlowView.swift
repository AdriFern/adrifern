import SwiftUI

struct OnboardingFlowView: View {
    @Environment(FamilyStore.self) private var store

    var body: some View {
        NavigationStack {
            if store.joinNeedsProfile {
                JoinProfileView()
            } else {
                WelcomeView()
            }
        }
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    @Environment(FamilyStore.self) private var store
    @State private var isRestoring = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 160, height: 160)
                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.bottom, 28)
            .accessibilityHidden(true)

            Text("Nido")
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text("The shared custody calendar that keeps both parents on the same page.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 8)

            Spacer()
            Spacer()

            VStack(spacing: 12) {
                NavigationLink {
                    CreateFamilyView()
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

                // Recovery path after a reinstall or new phone.
                Button {
                    Task {
                        isRestoring = true
                        _ = await store.reconnectExistingCalendar()
                        isRestoring = false
                    }
                } label: {
                    if isRestoring {
                        ProgressView()
                    } else {
                        Text("Restore an existing calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isRestoring)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
    }
}

// MARK: - Create family

struct CreateFamilyView: View {
    @Environment(FamilyStore.self) private var store
    @State private var myName = ""
    @State private var childName = ""
    @State private var colorHex = Palette.defaultA
    @State private var isCreating = false
    @State private var showInvite = false
    @FocusState private var focusedField: Field?

    private enum Field { case myName, childName }

    private var canContinue: Bool {
        !myName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !childName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Let's set things up")
                        .font(.title.bold())
                    Text("You'll invite your co-parent in the next step.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Adrián", text: $myName)
                        .textContentType(.givenName)
                        .focused($focusedField, equals: .myName)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .childName }
                        .padding(14)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your child's name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Luna", text: $childName)
                        .focused($focusedField, equals: .childName)
                        .submitLabel(.done)
                        .padding(14)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your color on the calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ColorSwatchPicker(selection: $colorHex)
                }

                Spacer(minLength: 12)

                Button {
                    Task {
                        isCreating = true
                        let success = await store.createFamily(
                            myName: myName.trimmingCharacters(in: .whitespaces),
                            childName: childName.trimmingCharacters(in: .whitespaces),
                            colorHex: colorHex
                        )
                        isCreating = false
                        if success { showInvite = true }
                    }
                } label: {
                    if isCreating {
                        ProgressView().tint(.white)
                    } else {
                        Text("Create calendar")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canContinue || isCreating)
                .opacity(canContinue ? 1 : 0.5)
            }
            .padding(24)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showInvite) {
            InviteView(isOnboarding: true)
                .navigationBarBackButtonHidden(true)
        }
    }
}

// MARK: - Join profile (step 2 for the invited parent)

struct JoinProfileView: View {
    @Environment(FamilyStore.self) private var store
    @State private var myName = ""
    @State private var colorHex = Palette.defaultB
    @State private var isSaving = false

    private var takenColor: String? { store.family?.colorA }

    private var canContinue: Bool {
        !myName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Almost there!")
                        .font(.title.bold())
                    if let family = store.family {
                        Text("You're joining \(family.childName)'s calendar with \(family.name(of: .parentA)).")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("You're joining a shared custody calendar.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. María", text: $myName)
                        .textContentType(.givenName)
                        .padding(14)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Your color on the calendar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ColorSwatchPicker(selection: $colorHex, disabledHex: takenColor)
                }

                Spacer(minLength: 12)

                if store.family == nil {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Waiting for the calendar to sync…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Button {
                    Task {
                        isSaving = true
                        _ = await store.completeJoin(
                            myName: myName.trimmingCharacters(in: .whitespaces),
                            colorHex: colorHex
                        )
                        isSaving = false
                    }
                } label: {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("Start using Nido")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canContinue || isSaving || store.family == nil)
                .opacity(canContinue && store.family != nil ? 1 : 0.5)
            }
            .padding(24)
        }
        .background(Theme.background)
        .onAppear {
            if let taken = takenColor, colorHex == taken {
                colorHex = Palette.options.first { $0 != taken } ?? Palette.defaultB
            }
        }
        .onChange(of: store.family) { _, _ in
            if let taken = takenColor, colorHex == taken {
                colorHex = Palette.options.first { $0 != taken } ?? Palette.defaultB
            }
        }
    }
}
