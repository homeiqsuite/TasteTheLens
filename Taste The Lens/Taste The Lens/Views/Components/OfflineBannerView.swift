import SwiftUI

struct OfflineBannerView: View {
    let isConnected: Bool
    let wasDisconnected: Bool
    let queueCount: Int
    let isProcessingQueue: Bool
    let processingIndex: Int?
    let onProcess: () -> Void

    @AppStorage("hasSeenOfflineQueueDisclaimer") private var hasSeenDisclaimer = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            bannerContent
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.darkCardSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.darkCardBorder, lineWidth: 0.5)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.top, 60)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(
            reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.4, dampingFraction: 0.85),
            value: isConnected
        )
        .animation(
            reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.4, dampingFraction: 0.85),
            value: wasDisconnected
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var bannerContent: some View {
        if isProcessingQueue, let index = processingIndex {
            // Processing state
            HStack(spacing: 10) {
                ProgressView()
                    .tint(Theme.gold)
                Text("Processing \(index + 1) of \(queueCount)…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.darkTextPrimary)
            }
        } else if !isConnected {
            // Offline state
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.gold)
                    if queueCount > 0 {
                        Text("You're offline · \(queueCount) queued")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.darkTextPrimary)
                    } else {
                        Text("You're offline")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.darkTextPrimary)
                    }
                }

                // First-time disclaimer (show whenever queued and not yet acknowledged)
                if queueCount > 0 && !hasSeenDisclaimer {
                    Text("Photos are saved locally and processed when online. Each uses 1 credit.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.darkTextTertiary)
                        .multilineTextAlignment(.center)
                        .onAppear { hasSeenDisclaimer = true }
                }
            }
        } else if wasDisconnected {
            // Back online state
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                    Text("Back online")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.darkTextPrimary)
                }

                if queueCount > 0 {
                    Button(action: onProcess) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Process \(queueCount) photo\(queueCount == 1 ? "" : "s") (\(queueCount) credit\(queueCount == 1 ? "" : "s"))")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Theme.darkBg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.gold)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var accessibilityText: String {
        if isProcessingQueue, let index = processingIndex {
            return "Processing queued photo \(index + 1) of \(queueCount)"
        } else if !isConnected {
            if queueCount > 0 {
                return "You're offline. \(queueCount) photos queued for processing."
            }
            return "You're offline."
        } else if wasDisconnected {
            if queueCount > 0 {
                return "Back online. \(queueCount) photos ready to process."
            }
            return "Back online."
        }
        return ""
    }
}
