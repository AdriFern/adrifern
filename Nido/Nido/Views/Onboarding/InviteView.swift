import CoreImage.CIFilterBuiltins
import SwiftUI

/// Shows the invitation QR code and share link for the co-parent.
/// Used both at the end of onboarding and from Settings.
struct InviteView: View {
    @Environment(FamilyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var familyID: String
    var isOnboarding: Bool

    var body: some View {
        @Bindable var store = store
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Invite your co-parent")
                        .font(.title.bold())
                    Text("They scan this code with their iPhone camera, or you can send them the link.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.top, 16)

                if let url = store.shareURL(for: familyID) {
                    QRCodeView(text: url.absoluteString)
                        .frame(width: 232, height: 232)
                        .padding(20)
                        .background(.white, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
                        .accessibilityLabel(Text("Invitation QR code"))

                    ShareLink(item: url, message: Text("Join our custody calendar on Nido")) {
                        Label("Send invitation link", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)

                    // WhatsApp shortcut: opens the recipient picker with
                    // the invitation message prefilled.
                    if let whatsAppURL = WhatsAppLink.url(number: "", text: WhatsAppLink.inviteMessage(url: url)) {
                        Link(destination: whatsAppURL) {
                            Label("Send via WhatsApp", systemImage: "bubble.left.and.bubble.right.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .padding(.horizontal, 24)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        InviteHintRow(number: 1, text: String(localized: "Your co-parent installs Nido on their iPhone."))
                        InviteHintRow(number: 2, text: String(localized: "They scan the code or tap the link you send."))
                        InviteHintRow(number: 3, text: String(localized: "iCloud connects you both — everything stays private between you two."))
                    }
                    .padding(20)
                    .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
                    .padding(.horizontal, 24)
                } else {
                    ProgressView("Preparing invitation…")
                        .padding(40)
                }

                if isOnboarding {
                    Button {
                        store.enterApp()
                    } label: {
                        Text("Go to the calendar")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                } else {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(Theme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // Mints a fresh invitation when the previous one was closed
        // (e.g. after removing a co-parent).
        .task { await store.ensureInvitationReady(familyID: familyID) }
        // Errors must be able to present when this view sits in a sheet.
        .alert(item: $store.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

private struct InviteHintRow: View {
    var number: Int
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.15), in: Circle())
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - QR rendering

struct QRCodeView: View {
    var text: String

    var body: some View {
        if let image = Self.generate(from: text) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "qrcode")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
        }
    }

    static func generate(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
