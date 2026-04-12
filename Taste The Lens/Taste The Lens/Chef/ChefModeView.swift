import SwiftUI

struct ChefModeView: View {
    var context: ChefSelectionContext = .defaultChef

    @AppStorage("selectedChef") private var selectedChef = "default"
    @State private var centeredChefID: ChefPersonality.ID?
    @State private var showPaywall = false
    @State private var showCustomChefEditor = false
    @Environment(\.dismiss) private var dismiss

    private var currentChef: ChefPersonality {
        ChefPersonality(rawValue: selectedChef) ?? .defaultChef
    }

    private var centeredChef: ChefPersonality {
        if let id = centeredChefID {
            return ChefPersonality(rawValue: id) ?? .defaultChef
        }
        return currentChef
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    if context == .defaultChef {
                        currentModeCard
                    }

                    chefCarousel

                    pageIndicatorDots

                    chefDetailSection

                    reassuranceBanner
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
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
            if centeredChefID == nil {
                centeredChefID = selectedChef
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(context == .forThisRecipe ? "Chef for This Recipe" : "Chef Mode")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.darkTextPrimary)

            Text(context == .forThisRecipe ? "Applies to this generation only" : "Swipe to choose how you want to cook")
                .font(.system(size: 15))
                .foregroundStyle(Theme.darkTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Current Mode Status Card

    private var currentModeCard: some View {
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

    // MARK: - Carousel

    private var chefCarousel: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width - 60
            let horizontalInset = (geo.size.width - cardWidth) / 2

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(ChefPersonality.allCases) { chef in
                        let isSelected = selectedChef == chef.rawValue
                        let isLocked = chef != .defaultChef &&
                            EntitlementManager.shared.requiresUpgrade(for: .chefPersonalities)

                        ChefCarouselCard(
                            chef: chef,
                            isSelected: isSelected,
                            isLocked: isLocked,
                            onSelect: { handleChefTap(chef) }
                        )
                        .frame(width: cardWidth)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(phase.isIdentity ? 1.0 : 0.88)
                                .opacity(phase.isIdentity ? 1.0 : 0.6)
                        }
                        .id(chef.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $centeredChefID)
            .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
        }
        .frame(height: 400)
    }

    // MARK: - Page Indicator Dots

    private var pageIndicatorDots: some View {
        HStack(spacing: 8) {
            ForEach(ChefPersonality.allCases) { chef in
                Circle()
                    .fill(centeredChefID == chef.id ? chef.theme.accent : Theme.darkCardBorder)
                    .frame(
                        width: centeredChefID == chef.id ? 10 : 7,
                        height: centeredChefID == chef.id ? 10 : 7
                    )
                    .animation(.easeInOut(duration: 0.2), value: centeredChefID)
            }
        }
    }

    // MARK: - Detail Section

    private var chefDetailSection: some View {
        let chef = centeredChef
        let chefTheme = chef.theme
        let isLocked = chef != .defaultChef &&
            EntitlementManager.shared.requiresUpgrade(for: .chefPersonalities)
        let isSelected = selectedChef == chef.rawValue

        return VStack(spacing: 16) {
            // Description card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: chef.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(chefTheme.accent)
                    Text(chef.displayName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.darkTextPrimary)
                }

                Text(chef.description)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(chef.tagline)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .italic()
                    .foregroundStyle(chefTheme.accent.opacity(0.8))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.darkCardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(chefTheme.accent.opacity(0.2), lineWidth: 0.5)
                    )
            )

            // CTA button
            Button {
                handleChefTap(chef)
            } label: {
                HStack(spacing: 8) {
                    if isLocked {
                        Image(systemName: "lock.fill")
                        Text("Unlock with Pro")
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Currently Active")
                    } else if chef == .custom && !CustomChefConfig.isConfigured {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Custom Chef")
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Select \(chef.displayName)")
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isSelected ? chefTheme.accent : Theme.darkBg)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected
                            ? chefTheme.accent.opacity(0.12)
                            : chefTheme.accent)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? chefTheme.accent.opacity(0.3) : .clear,
                                lineWidth: 1)
                )
            }
            .disabled(isSelected && chef != .custom)
        }
        .animation(.easeInOut(duration: 0.3), value: centeredChefID)
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

    // MARK: - Selection Logic

    private func handleChefTap(_ chef: ChefPersonality) {
        let isLocked = chef != .defaultChef &&
            EntitlementManager.shared.requiresUpgrade(for: .chefPersonalities)

        if isLocked {
            HapticManager.light()
            showPaywall = true
        } else if chef == .custom {
            HapticManager.light()
            if !CustomChefConfig.isConfigured || selectedChef == chef.rawValue {
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
    }
}

#Preview {
    ChefModeView()
        .preferredColorScheme(.dark)
}
