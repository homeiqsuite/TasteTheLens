import SwiftUI

struct ChefModeView: View {
    var context: ChefSelectionContext = .defaultChef

    @AppStorage("selectedChef") private var selectedChef = "default"
    @State private var showPaywall = false
    @State private var showCustomChefEditor = false
    @Environment(\.dismiss) private var dismiss

    private var currentChef: ChefPersonality {
        ChefPersonality(rawValue: selectedChef) ?? .defaultChef
    }

    private var comparisonChef: ChefPersonality {
        currentChef == .beginner ? .defaultChef : .beginner
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection

                        if context == .defaultChef {
                            currentModeCard(proxy: proxy)
                        }

                        chefSelectionGrid

                        reassuranceBanner

                        quickComparisonSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .background(Theme.darkBg.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.gold)
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
            if EntitlementManager.shared.requiresUpgrade(for: .chefPersonalities) && selectedChef != "default" {
                selectedChef = "default"
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(context == .forThisRecipe ? "Chef for This Recipe" : "Chef Mode")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.darkTextPrimary)

            Text(context == .forThisRecipe ? "Applies to this generation only" : "Choose how you want to cook today")
                .font(.system(size: 15))
                .foregroundStyle(Theme.darkTextSecondary)
        }
    }

    // MARK: - Current Mode Status Card

    private func currentModeCard(proxy: ScrollViewProxy) -> some View {
        let chef = currentChef
        let chefTheme = chef.theme

        return HStack(spacing: 14) {
            Circle()
                .fill(chefTheme.accent.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: chef.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(chefTheme.accent)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Current Mode")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.darkTextTertiary)

                HStack(spacing: 8) {
                    Text(chef.displayName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.darkTextPrimary)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.12))
                    )
                }

                Text(chef.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.darkTextSecondary)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation {
                    proxy.scrollTo(chef.id, anchor: .center)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12))
                    Text("Learn More")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Theme.darkTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .stroke(Theme.darkCardBorder, lineWidth: 1)
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.darkCardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.darkCardBorder, lineWidth: 0.5)
                )
        )
    }

    // MARK: - Chef Selection Grid

    private var chefSelectionGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CHOOSE YOUR CHEF")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.darkTextSecondary)
                .tracking(1.2)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14),
            ], spacing: 14) {
                ForEach(ChefPersonality.allCases) { chef in
                    chefGridCard(chef)
                        .id(chef.id)
                }
            }
        }
    }

    private func chefGridCard(_ chef: ChefPersonality) -> some View {
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
                HapticManager.light()
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedChef = chef.rawValue
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Top row: icon + selection indicator
                HStack {
                    Circle()
                        .fill(chefTheme.accent.opacity(isSelected ? 0.20 : 0.10))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: chef.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(chefTheme.accent)
                        )

                    Spacer()

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.darkTextHint)
                    } else if isSelected && chef == .custom && CustomChefConfig.isConfigured {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(chefTheme.accent)
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(chefTheme.accent)
                    } else {
                        Circle()
                            .stroke(Theme.darkTextHint, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                    }
                }

                // Chef name + subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(chef.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white : Theme.darkTextPrimary)

                    Text(chef.subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(chefTheme.accent)
                }

                // Description
                Text(chef.description)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Theme.darkTextSecondary : Theme.darkTextTertiary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                // Divider
                Rectangle()
                    .fill(Theme.darkCardBorder)
                    .frame(height: 0.5)

                // Best for section
                VStack(alignment: .leading, spacing: 6) {
                    Text("Best for:")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(chefTheme.accent)

                    ForEach(chef.bestFor) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(chefTheme.accent)
                                .frame(width: 16)

                            Text(item.text)
                                .font(.system(size: 12))
                                .foregroundStyle(isSelected ? Theme.darkTextSecondary : Theme.darkTextTertiary)
                        }
                    }
                }
            }
            .padding(14)
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
                color: isSelected ? chefTheme.accent.opacity(0.2) : .clear,
                radius: 12, y: 4
            )
            .opacity(isLocked ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reassurance Banner

    private var reassuranceBanner: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.yellow.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.yellow)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("You can switch anytime")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.darkTextPrimary)

                Text("Your Chef Mode can be changed at any time to match your cooking mood or ingredients.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.darkTextTertiary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.darkCardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.darkCardBorder, lineWidth: 0.5)
                )
        )
    }

    // MARK: - Quick Comparison

    private var quickComparisonSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("QUICK COMPARISON")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.darkTextSecondary)
                .tracking(1.2)

            HStack(spacing: 12) {
                comparisonCard(currentChef)
                comparisonCard(comparisonChef)
            }
        }
    }

    private func comparisonCard(_ chef: ChefPersonality) -> some View {
        let chefTheme = chef.theme

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(chefTheme.accent.opacity(0.15))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: chef.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(chefTheme.accent)
                    )

                Text(chef.displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(chefTheme.accent)
            }

            ForEach(chef.bestFor) { item in
                Text("• \(item.text)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.darkTextSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.darkCardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(chefTheme.accent.opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}

#Preview {
    ChefModeView()
        .preferredColorScheme(.dark)
}
