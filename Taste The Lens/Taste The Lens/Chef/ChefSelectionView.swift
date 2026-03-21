import SwiftUI

struct ChefSelectionView: View {
    @AppStorage("selectedChef") private var selectedChef = "default"
    @State private var showPaywall = false

    private let gold = Theme.gold

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Chef")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ChefPersonality.allCases) { chef in
                        chefCard(chef)
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .featureGated(.chefPersonalities))
        }
        .onAppear {
            // Reset to default if user lost subscription and had a premium chef selected
            if EntitlementManager.shared.requiresUpgrade(for: .chefPersonalities) && selectedChef != "default" {
                selectedChef = "default"
            }
        }
    }

    private func chefCard(_ chef: ChefPersonality) -> some View {
        let isSelected = selectedChef == chef.rawValue
        let isLocked = chef != .defaultChef && EntitlementManager.shared.requiresUpgrade(for: .chefPersonalities)

        return Button {
            if isLocked {
                HapticManager.light()
                showPaywall = true
            } else {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                selectedChef = chef.rawValue
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: chef.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? gold : Theme.textTertiary)

                    Text(chef.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textPrimary)

                    if isLocked {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }

                Text(chef.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? gold : Theme.textSecondary)

                Text(chef.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(width: 200, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Theme.primaryLight : Theme.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? gold : Theme.cardBorder, lineWidth: isSelected ? 1.5 : 0.5)
            )
            .opacity(isLocked ? 0.7 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ChefSelectionView()
        .padding()
        .background(Theme.darkBg)
}
