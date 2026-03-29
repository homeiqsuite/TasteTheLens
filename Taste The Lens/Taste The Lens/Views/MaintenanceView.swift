import SwiftUI

struct MaintenanceView: View {
    let message: String

    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.gold)

                Text("Under Maintenance")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.darkTextPrimary)

                Text(message)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    Task { await RemoteConfigManager.shared.fetch() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                        Text("Check Again")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.gold.opacity(0.12))
                    .clipShape(Capsule())
                }
                .padding(.top, 8)

                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }
}
