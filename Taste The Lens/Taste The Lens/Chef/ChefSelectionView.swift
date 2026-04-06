import SwiftUI

enum ChefSelectionContext {
    case defaultChef
    case forThisRecipe

    var title: String {
        switch self {
        case .defaultChef: return "Your Chef"
        case .forThisRecipe: return "Chef for this recipe"
        }
    }

    var subtitle: String? {
        switch self {
        case .defaultChef: return nil
        case .forThisRecipe: return "Applies to this generation only"
        }
    }
}

struct ChefSelectionView: View {
    var context: ChefSelectionContext = .defaultChef
    var showHeader: Bool = true
    @AppStorage("selectedChef") private var selectedChef = "default"
    @State private var showPaywall = false
    @State private var showCustomChefEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showHeader {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .textCase(.uppercase)
                        .tracking(1.2)
                    if let subtitle = context.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.darkTextHint)
                    }
                }
            }

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
        .sheet(isPresented: $showCustomChefEditor) {
            CustomChefEditorView()
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
        let chefTheme = chef.theme

        return Button {
            if isLocked {
                HapticManager.light()
                showPaywall = true
            } else if chef == .custom {
                HapticManager.light()
                if !CustomChefConfig.isConfigured || isSelected {
                    showCustomChefEditor = true
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedChef = chef.rawValue
                    }
                }
            } else {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedChef = chef.rawValue
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    // Chef icon in a tinted circle
                    Circle()
                        .fill(chefTheme.accent.opacity(isSelected ? 0.20 : 0.10))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Image(systemName: chef.icon)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(chefTheme.accent)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(chef.displayName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(isSelected ? Color.white : Theme.darkTextPrimary)

                        Text(chef.subtitle)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? chefTheme.accent : Theme.darkTextTertiary)
                    }

                    Spacer(minLength: 0)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.darkTextHint)
                    } else if chef == .custom && isSelected && CustomChefConfig.isConfigured {
                        // Edit affordance for configured custom chef
                        Button {
                            showCustomChefEditor = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(chefTheme.accent)
                        }
                    }
                }

                Text(chef.description)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Theme.darkTextSecondary : Theme.darkTextTertiary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(width: 250, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? chefTheme.accent.opacity(0.08) : Theme.darkCardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? chefTheme.accent.opacity(0.6) : Theme.darkCardBorder,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .shadow(
                color: isSelected ? chefTheme.accent.opacity(0.15) : .clear,
                radius: 8, y: 2
            )
            .opacity(isLocked ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ChefSelectionView()
        .padding()
        .background(Theme.darkBg)
}
