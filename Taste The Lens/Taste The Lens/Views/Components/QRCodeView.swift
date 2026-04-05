import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeSheet: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Text("Scan to Join")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.gold)

                        Text("Share this QR code so friends can scan and join the menu directly.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.darkTextTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    if let qrImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 240, height: 240)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.white)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Theme.darkSurface)
                            .frame(width: 280, height: 280)
                            .overlay(ProgressView().tint(Theme.gold))
                    }

                    // Invite URL label
                    Text(url.absoluteString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.darkTextHint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 24)

                    // Share button
                    Button {
                        shareURL()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Link")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Theme.gold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.gold.opacity(0.4), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 32)
            }
            .navigationTitle("Invite QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
            .onAppear {
                qrImage = generateQRCode(from: url.absoluteString)
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up so it renders crisply at display size
        let scale: CGFloat = 10
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func shareURL() {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           var topVC = windowScene.windows.first?.rootViewController {
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }
}
