import AVFoundation
import SwiftUI
import VisionKit

/// Entry point for the invited parent: tap the shared link, scan the QR code
/// in-app, or paste the invitation link manually.
struct JoinFamilyView: View {
    @Environment(FamilyStore.self) private var store
    @State private var pastedLink = ""
    @State private var showScanner = false
    @State private var invalidLink = false

    private var scannerAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Join your family's calendar")
                        .font(.title.bold())
                    Text("Ask your co-parent to send you the invitation from their Nido app.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 14) {
                    Label {
                        Text("Got the invitation by message or email? Just tap the link — it opens Nido automatically.")
                    } icon: {
                        Image(systemName: "hand.tap")
                            .foregroundStyle(Color.accentColor)
                    }
                    .font(.subheadline)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))

                if scannerAvailable {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan QR code", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Or paste the invitation link")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("https://www.icloud.com/share/…", text: $pastedLink)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .padding(14)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    if invalidLink {
                        Text("That link doesn't look like a Nido invitation.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Button {
                        join(with: pastedLink)
                    } label: {
                        if store.isAcceptingInvite {
                            ProgressView()
                        } else {
                            Text("Join")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(pastedLink.trimmingCharacters(in: .whitespaces).isEmpty || store.isAcceptingInvite)
                }
            }
            .padding(24)
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showScanner) {
            QRScannerSheet { scanned in
                showScanner = false
                join(with: scanned)
            }
        }
    }

    private func join(with text: String) {
        invalidLink = false
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), trimmed.lowercased().contains("icloud.com") else {
            invalidLink = true
            return
        }
        Task { await store.join(with: url) }
    }
}

// MARK: - QR scanner

struct QRScannerSheet: View {
    var onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var cameraAllowed: Bool?

    var body: some View {
        NavigationStack {
            Group {
                switch cameraAllowed {
                case .some(true):
                    QRScannerView(onScan: onScan)
                        .ignoresSafeArea()
                case .some(false):
                    ContentUnavailableView(
                        "Camera access needed",
                        systemImage: "camera",
                        description: Text("Allow camera access for Nido in the iPhone Settings app to scan the invitation code.")
                    )
                case .none:
                    ProgressView()
                }
            }
            .navigationTitle(Text("Scan invitation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                cameraAllowed = true
            case .notDetermined:
                cameraAllowed = await AVCaptureDevice.requestAccess(for: .video)
            default:
                cameraAllowed = false
            }
        }
    }
}

private struct QRScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !context.coordinator.started {
            context.coordinator.started = true
            try? scanner.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        var started = false
        private var delivered = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !delivered else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    delivered = true
                    dataScanner.stopScanning()
                    onScan(value)
                    break
                }
            }
        }
    }
}
