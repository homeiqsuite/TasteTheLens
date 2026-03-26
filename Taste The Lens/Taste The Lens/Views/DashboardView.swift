import SwiftUI
import SwiftData
import os

private let logger = makeLogger(category: "Dashboard")

struct DashboardView: View {
    @Bindable var vm: MainViewModel
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedRecipe: Recipe?
    @State private var showChefPicker = false
    @State private var progressAnimated = false
    @State private var heroGlowPulse = false
    @AppStorage("selectedChef") private var selectedChef = "default"

    private let authManager = AuthManager.shared
    private let challengeService = ChallengeService.shared
    private let menuService = TastingMenuService.shared
    private let impactService = CommunityImpactService.shared

    private var chefTheme: ChefTheme {
        let chef = ChefPersonality(rawValue: selectedChef) ?? .defaultChef
        return chef.theme
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                greetingSection
                heroCard
                recentRecipesSection
                communityImpactCard
                chefModeCard
                if EntitlementManager.shared.hasAccess(to: .fullChallenges) {
                    challengesSection
                }
                if EntitlementManager.shared.hasAccess(to: .fullTastingMenus) {
                    tastingMenuCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(chefTheme.dashboardBg.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.4), value: selectedChef)
        .sheet(item: $selectedRecipe) { recipe in
            NavigationStack {
                RecipeCardView(recipe: recipe)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { selectedRecipe = nil }
                                .foregroundStyle(Theme.primary)
                        }
                    }
            }
        }
        .sheet(isPresented: $showChefPicker) {
            NavigationStack {
                ZStack {
                    Theme.darkBg.ignoresSafeArea()
                    ChefSelectionView()
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Theme.darkBg, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showChefPicker = false }
                            .foregroundStyle(Theme.gold)
                    }
                }
                .presentationDetents([.medium])
            }
        }
        .refreshable {
            await refreshDashboard()
        }
        .task {
            await loadDashboardData()
        }
    }

    private func loadDashboardData() async {
        async let statsTask: () = impactService.fetchStats()
        async let challengesTask: () = { try? await challengeService.fetchChallenges(filter: .trending) }()
        async let menusTask: () = {
            if authManager.isAuthenticated {
                try? await menuService.fetchMyMenus()
            }
        }()
        _ = await (statsTask, challengesTask, menusTask)
    }

    private func refreshDashboard() async {
        async let dashboardTask: () = loadDashboardData()
        async let creditsTask: () = UsageTracker.shared.syncCreditsFromServer()
        async let usageTask: () = UsageTracker.shared.syncUsageFromServer()
        async let subscriptionTask: () = StoreManager.shared.updateSubscriptionStatus()
        _ = await (dashboardTask, creditsTask, usageTask, subscriptionTask)
        logger.info("Dashboard refreshed")
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        HStack(alignment: .center) {
            Text("\(greetingText), \(displayName)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(chefTheme.textPrimary)

            Spacer()

            Button {
                vm.showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(chefTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(chefTheme.accent.opacity(0.12))
                    .clipShape(Circle())
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var displayName: String {
        if authManager.isAuthenticated {
            return authManager.displayName ?? "Chef"
        }
        return "Chef"
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        Button {
            HapticManager.medium()
            vm.navigateToCamera()
        } label: {
            ZStack {
                // Themed gradient background
                RoundedRectangle(cornerRadius: 28)
                    .fill(chefTheme.heroGradient)

                // Sparkle/glow overlay
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.white.opacity(0.05),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 200
                        )
                    )

                // Subtle light particles
                GeometryReader { geo in
                    ForEach(0..<6, id: \.self) { i in
                        Circle()
                            .fill(Color.white.opacity(Double.random(in: 0.15...0.35)))
                            .frame(width: CGFloat.random(in: 3...8))
                            .position(
                                x: CGFloat.random(in: 20...geo.size.width - 20),
                                y: CGFloat.random(in: 20...geo.size.height - 20)
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 28))

                VStack(spacing: 16) {
                    // Chef-specific icon with glow
                    ZStack {
                        // Glow behind icon
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 90, height: 90)
                            .blur(radius: 20)
                            .scaleEffect(heroGlowPulse ? 1.1 : 0.9)
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: heroGlowPulse
                            )

                        Image(systemName: chefTheme.heroIcon)
                            .font(.system(size: 40, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    }

                    VStack(spacing: 6) {
                        Text("Snap a Photo")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                        Text(chefTheme.heroSubtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(2)
                    }

                    // CTA button
                    Text("Snap a Photo")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(chefTheme.accentDeep)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        )
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 260)
            .shadow(color: chefTheme.accent.opacity(0.35), radius: 20, y: 10)
        }
        .buttonStyle(PremiumCardButtonStyle())
        .onAppear { heroGlowPulse = true }
    }

    // MARK: - Chef Mode

    private var chefModeCard: some View {
        let chef = ChefPersonality(rawValue: selectedChef) ?? .defaultChef

        return Button {
            HapticManager.light()
            showChefPicker = true
        } label: {
            HStack(spacing: 14) {
                // Chef icon
                Circle()
                    .fill(chefTheme.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: chef.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(chefTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Chef Mode")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(chefTheme.textPrimary)
                    Text(chef.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(chefTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(chefTheme.textQuaternary)
            }
            .themedCard(chefTheme)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    // MARK: - Community Impact

    private var communityImpactCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(chefTheme.impactColor.opacity(0.12))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(chefTheme.impactColor)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Community Impact")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(chefTheme.textPrimary)
                    Text("Every recipe helps feed someone")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(chefTheme.textTertiary)
                }

                Spacer()
            }

            HStack(spacing: 0) {
                // Remaining / To Go
                VStack(spacing: 4) {
                    if impactService.isLoaded {
                        let remaining = 25 - (impactService.totalGenerations % 25)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(remaining)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(chefTheme.impactColor)
                            Text("TO GO")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(chefTheme.impactColor.opacity(0.7))
                        }
                    } else {
                        Text("—")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(chefTheme.impactColor)
                    }
                    Text("Meals Donated")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(chefTheme.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(chefTheme.cardBorder)
                    .frame(width: 1, height: 40)

                // Recipes Created
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(impactService.isLoaded ? "\(impactService.totalGenerations)" : "—")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(chefTheme.accent)
                            .contentTransition(.numericText())

                        if impactService.isLoaded && impactService.totalGenerations > 0 {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(chefTheme.accent)
                        }
                    }
                    Text("Recipes Created")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(chefTheme.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)

            // Progress bar
            if impactService.isLoaded {
                let progress = Double(impactService.totalGenerations % 25) / 25.0
                let remaining = 25 - (impactService.totalGenerations % 25)

                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(chefTheme.impactColor.opacity(0.12))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(chefTheme.impactGradient)
                                .frame(width: geo.size.width * (progressAnimated ? progress : 0), height: 8)
                                .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: progressAnimated)
                        }
                    }
                    .frame(height: 8)

                    Text("You're \(remaining) recipe\(remaining == 1 ? "" : "s") away from feeding someone!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(chefTheme.textSecondary)
                }
                .onAppear { progressAnimated = true }
            }
        }
        .themedCard(chefTheme)
    }

    // MARK: - Challenges

    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Cooking Challenges")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(chefTheme.textPrimary)
                Spacer()
                if !challengeService.challenges.isEmpty {
                    Button {
                        vm.showChallengeFeed = true
                    } label: {
                        Text("See All")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(chefTheme.accent)
                    }
                }
            }

            if challengeService.challenges.isEmpty {
                challengeEmptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(challengeService.challenges.prefix(5))) { challenge in
                            challengePreviewCard(challenge)
                        }
                    }
                }
            }
        }
    }

    private var challengeEmptyState: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(chefTheme.accent.opacity(0.12))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 22))
                        .foregroundStyle(chefTheme.accent)
                )

            VStack(spacing: 4) {
                Text("No challenges yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(chefTheme.textSecondary)
                Text("Create a recipe to start one")
                    .font(.system(size: 13))
                    .foregroundStyle(chefTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(chefTheme.cardBg)
                .shadow(color: chefTheme.cardShadow, radius: 12, y: 4)
        )
    }

    private func challengePreviewCard(_ challenge: ChallengeDTO) -> some View {
        Button {
            vm.showChallengeFeed = true
        } label: {
            ChallengePreviewThumbnail(challenge: challenge, chefTheme: chefTheme)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    // MARK: - Tasting Menu

    private var tastingMenuCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if authManager.isAuthenticated && !menuService.myMenus.isEmpty {
                HStack {
                    Text("Tasting Menus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(chefTheme.textPrimary)
                    Spacer()
                    Button {
                        vm.showTastingMenus = true
                    } label: {
                        Text("See All")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(chefTheme.accent)
                    }
                }

                ForEach(Array(menuService.myMenus.prefix(2))) { menu in
                    menuPreviewCard(menu)
                }
            }

            createMenuCard
        }
    }

    private func menuPreviewCard(_ menu: TastingMenuDTO) -> some View {
        Button {
            vm.showTastingMenus = true
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(chefTheme.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "menucard")
                            .font(.system(size: 18))
                            .foregroundStyle(chefTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(menu.theme)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(chefTheme.textPrimary)
                    Text("\(menu.courseCount) courses · \(menu.status.capitalized)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(chefTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chefTheme.textQuaternary)
            }
            .themedCard(chefTheme)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    private var createMenuCard: some View {
        Button {
            if authManager.isAuthenticated {
                vm.showTastingMenus = true
            } else {
                vm.showSettings = true
            }
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(chefTheme.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(chefTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Create a Tasting Menu")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(chefTheme.textPrimary)
                    Text(authManager.isAuthenticated
                         ? "Design a multi-course experience"
                         : "Sign in to create themed menus with friends")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(chefTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chefTheme.textQuaternary)
            }
            .themedCard(chefTheme)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    // MARK: - Recent Recipes

    private var recentRecipesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("My Recipes")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(chefTheme.textPrimary)
                Spacer()
                if !recipes.isEmpty {
                    Button {
                        vm.showSavedRecipes = true
                    } label: {
                        Text("See All")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(chefTheme.accent)
                    }
                }
            }

            if recipes.isEmpty {
                emptyRecipesState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(Array(recipes.prefix(5))) { recipe in
                            recentRecipeCard(recipe)
                        }
                    }
                }
            }
        }
    }

    private var emptyRecipesState: some View {
        Button {
            HapticManager.medium()
            vm.navigateToCamera()
        } label: {
            HStack(spacing: 16) {
                // Playful food illustration using layered icons
                ZStack {
                    Circle()
                        .fill(chefTheme.accent.opacity(0.10))
                        .frame(width: 72, height: 72)

                    // Layered food icons for playful feel
                    Image(systemName: "carrot.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(chefTheme.accentOrange)
                        .offset(x: -14, y: -10)

                    Image(systemName: "leaf.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green.opacity(0.6))
                        .offset(x: 16, y: -14)

                    Image(systemName: "camera.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(chefTheme.accent)

                    Image(systemName: "fork.knife")
                        .font(.system(size: 14))
                        .foregroundStyle(chefTheme.accentDeep)
                        .offset(x: 14, y: 12)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("No recipes yet")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(chefTheme.textPrimary)

                    Text("Your first recipe is waiting")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(chefTheme.textTertiary)

                    Text("Snap Your First Recipe")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(chefTheme.accentDeep)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(chefTheme.ctaGradient)
                                .opacity(0.18)
                        )
                        .overlay(
                            Capsule()
                                .stroke(chefTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.top, 2)
                }

                Spacer()
            }
            .themedCard(chefTheme)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    private func recentRecipeCard(_ recipe: Recipe) -> some View {
        Button {
            selectedRecipe = recipe
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // Dish image thumbnail
                Color.clear
                    .frame(width: 160, height: 120)
                    .overlay {
                        if let imageData = recipe.generatedDishImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(chefTheme.accent.opacity(0.08))
                                .overlay(
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 28))
                                        .foregroundStyle(chefTheme.accent.opacity(0.3))
                                )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.dishName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(chefTheme.textPrimary)
                        .lineLimit(2)
                        .frame(width: 160, alignment: .leading)

                    Text("AI Generated · \(recipe.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(chefTheme.textQuaternary)
                }
            }
            .frame(width: 160)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }
}

// MARK: - Themed Card Modifier

private struct ThemedCard: ViewModifier {
    let theme: ChefTheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.cardBg)
                    .shadow(color: theme.cardShadow, radius: 12, y: 4)
                    .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
            )
    }
}

extension View {
    fileprivate func themedCard(_ theme: ChefTheme) -> some View {
        modifier(ThemedCard(theme: theme))
    }
}

// MARK: - Premium Button Style

/// Subtle scale + lift animation on press for all interactive cards.
struct PremiumCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Challenge Preview Thumbnail

private struct ChallengePreviewThumbnail: View {
    let challenge: ChallengeDTO
    let chefTheme: ChefTheme
    @State private var dishImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Color.clear
                .frame(width: 160, height: 100)
                .overlay {
                    if let image = dishImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(chefTheme.accent.opacity(0.08))
                            .overlay(
                                Image(systemName: "flag.checkered")
                                    .font(.system(size: 28))
                                    .foregroundStyle(chefTheme.accent.opacity(0.25))
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(challenge.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(chefTheme.textPrimary)
                .lineLimit(2)
                .frame(width: 160, alignment: .leading)
        }
        .frame(width: 160)
        .task {
            if let path = challenge.dishImagePath, !path.isEmpty {
                dishImage = await ChallengeService.shared.loadImage(path: path)
            }
        }
    }
}
