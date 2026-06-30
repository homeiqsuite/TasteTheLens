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
    @State private var showPaywall = false
    @State private var showMealPlans = false
    @AppStorage("selectedChef") private var selectedChef = "default"

    private let authManager = AuthManager.shared
    private let challengeService = ChallengeService.shared
    private let menuService = TastingMenuService.shared
    private let impactService = CommunityImpactService.shared

    /// Target number of recipes per week the metric ring fills toward.
    private let weeklyGoal = 5

    private var chefTheme: ChefTheme {
        let chef = ChefPersonality(rawValue: selectedChef) ?? .defaultChef
        return chef.theme
    }

    // MARK: - Computed Data

    private var cookingStreak: Int {
        let calendar = Calendar.current
        var streakDays = 0
        var checkDate = calendar.startOfDay(for: Date())
        let recipeDays = Set(recipes.map { calendar.startOfDay(for: $0.createdAt) })
        while recipeDays.contains(checkDate) {
            streakDays += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streakDays
    }

    private var recipesThisWeek: Int {
        let calendar = Calendar.current
        guard let startOfWeek = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: Date()).date else { return 0 }
        return recipes.filter { $0.createdAt >= startOfWeek }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                greetingSection
                heroMetricCard
                secondaryTiles
                chefModeCard
                mealPlanCard
                if let lastRecipe = recipes.first {
                    continueCookingSection(lastRecipe)
                }
                recentRecipesSection
                if RemoteConfigManager.shared.gauntletEnabled {
                    challengesSection
                }
                if RemoteConfigManager.shared.tastingMenusEnabled && EntitlementManager.shared.hasAccess(to: .fullTastingMenus) {
                    tastingMenuCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, DS.tabBarClearance + DS.Spacing.lg)
        }
        .background(chefTheme.dashboardBg.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.4), value: selectedChef)
        .refreshable {
            await refreshDashboard()
        }
        .sheet(item: $selectedRecipe) { recipe in
            NavigationStack {
                RecipeCardView(recipe: recipe, onDismiss: { selectedRecipe = nil })
            }
        }
        .sheet(isPresented: $showChefPicker) {
            ChefModeView(context: .defaultChef)
        }
        .sheet(isPresented: $showMealPlans) {
            SavedMealPlansView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .featureGated(.fullChallenges))
        }
        .task {
            await loadDashboardData()
        }
    }

    private func loadDashboardData() async {
        async let statsTask: () = impactService.fetchStats()
        async let challengesTask: () = challengeService.fetchDashboardChallenges()
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
        _ = await (dashboardTask, creditsTask, usageTask)
        logger.info("Dashboard refreshed")
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.dsCaption)
                    .foregroundStyle(chefTheme.textTertiary)
                Text(displayName)
                    .font(.dsTitle)
                    .foregroundStyle(chefTheme.textPrimary)
            }

            Spacer()

            Button {
                vm.showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(chefTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(chefTheme.accent.opacity(0.12))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Settings")
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

    // MARK: - Hero Metric Card

    private var heroMetricCard: some View {
        HStack(spacing: 18) {
            MetricRing(
                value: recipesThisWeek,
                goal: weeklyGoal,
                centerSubtitle: "of \(weeklyGoal)",
                accent: chefTheme.accent,
                valueColor: chefTheme.textPrimary,
                subtitleColor: chefTheme.textTertiary,
                size: .large
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Recipes this week")
                    .font(.dsSection)
                    .foregroundStyle(chefTheme.textPrimary)

                Text(weeklyProgressMessage)
                    .font(.dsBody)
                    .foregroundStyle(chefTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button {
                    HapticManager.medium()
                    vm.navigateToCamera()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Snap a Photo")
                            .font(.dsBodyEmph)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(chefTheme.accent))
                }
                .buttonStyle(PremiumCardButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .minimalCard(chefTheme, padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
    }

    private var weeklyProgressMessage: String {
        if recipesThisWeek == 0 {
            return "Snap your first dish to start the week."
        } else if recipesThisWeek >= weeklyGoal {
            return "Goal reached — \(recipesThisWeek) made this week. Keep cooking!"
        } else {
            let remaining = weeklyGoal - recipesThisWeek
            return "\(remaining) more to reach your weekly goal."
        }
    }

    // MARK: - Secondary Stat Tiles

    private var secondaryTiles: some View {
        HStack(spacing: 12) {
            statTile(icon: "flame.fill", value: cookingStreak, label: "Day streak")
            statTile(icon: "fork.knife", value: recipes.count, label: "Total recipes")
        }
    }

    private func statTile(icon: String, value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(chefTheme.accent)
                .frame(width: 36, height: 36)
                .background(chefTheme.accent.opacity(0.12))
                .clipShape(Circle())

            Text("\(value)")
                .font(.dsMetric)
                .foregroundStyle(chefTheme.textPrimary)
                .contentTransition(.numericText())

            Text(label)
                .font(.dsCaption)
                .foregroundStyle(chefTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .minimalCard(chefTheme)
    }

    // MARK: - Chef Mode

    private var chefModeCard: some View {
        let chef = ChefPersonality(rawValue: selectedChef) ?? .defaultChef

        return Button {
            HapticManager.light()
            showChefPicker = true
        } label: {
            HStack(spacing: 14) {
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
                        .font(.dsBodyEmph)
                        .foregroundStyle(chefTheme.textPrimary)
                    Text(chef.subtitle)
                        .font(.dsCaption)
                        .foregroundStyle(chefTheme.textTertiary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Change")
                        .font(.dsCaption)
                        .foregroundStyle(chefTheme.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(chefTheme.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .overlay(
                    Capsule()
                        .strokeBorder(chefTheme.accent, lineWidth: 1)
                )
            }
            .minimalCard(chefTheme)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    // MARK: - Meal Plan

    private var mealPlanCard: some View {
        Button {
            HapticManager.light()
            showMealPlans = true
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(chefTheme.accent.opacity(0.12))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "calendar")
                            .font(.system(size: 20))
                            .foregroundStyle(chefTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Weekly Meal Plan")
                        .font(.dsBodyEmph)
                        .foregroundStyle(chefTheme.textPrimary)
                    Text("A researched week of meals + grocery list")
                        .font(.dsCaption)
                        .foregroundStyle(chefTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chefTheme.textQuaternary)
            }
            .minimalCard(chefTheme)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    // MARK: - Continue Cooking

    private func continueCookingSection(_ lastRecipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue cooking")
                .font(.dsSection)
                .foregroundStyle(chefTheme.textPrimary)

            Button {
                selectedRecipe = lastRecipe
            } label: {
                HStack(spacing: 14) {
                    recipeThumbnail(lastRecipe, size: 80, radius: DS.Radius.tile)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(lastRecipe.dishName)
                            .font(.dsBodyEmph)
                            .foregroundStyle(chefTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text(lastRecipe.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.dsCaption)
                            .foregroundStyle(chefTheme.textTertiary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Continue")
                            .font(.dsCaption)
                            .foregroundStyle(chefTheme.accent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(chefTheme.accent)
                    }
                }
                .minimalCard(chefTheme, radius: DS.Radius.tile, padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 14))
            }
            .buttonStyle(PremiumCardButtonStyle())
        }
    }

    // MARK: - Recent Recipes

    private var recentRecipesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent recipes")
                    .font(.dsSection)
                    .foregroundStyle(chefTheme.textPrimary)
                Spacer()
                if !recipes.isEmpty {
                    Button {
                        vm.requestedTab = .saved
                    } label: {
                        Text("See All")
                            .font(.dsBodyEmph)
                            .foregroundStyle(chefTheme.accent)
                    }
                }
            }

            if recipes.isEmpty {
                emptyRecipesState
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(recipes.prefix(4))) { recipe in
                        recentRecipeRow(recipe)
                    }
                }
            }
        }
    }

    private func recentRecipeRow(_ recipe: Recipe) -> some View {
        Button {
            selectedRecipe = recipe
        } label: {
            HStack(spacing: 12) {
                recipeThumbnail(recipe, size: 56, radius: DS.Radius.chip)

                VStack(alignment: .leading, spacing: 3) {
                    Text(recipe.dishName)
                        .font(.dsBodyEmph)
                        .foregroundStyle(chefTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(recipe.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.dsCaption)
                        .foregroundStyle(chefTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chefTheme.textQuaternary)
            }
            .minimalCard(chefTheme, radius: DS.Radius.tile, padding: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 14))
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    private var emptyRecipesState: some View {
        Button {
            HapticManager.medium()
            vm.navigateToCamera()
        } label: {
            HStack(spacing: 16) {
                Circle()
                    .fill(chefTheme.accent.opacity(0.10))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(chefTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("No recipes yet")
                        .font(.dsBodyEmph)
                        .foregroundStyle(chefTheme.textPrimary)

                    Text("Snap a photo to create your first dish.")
                        .font(.dsCaption)
                        .foregroundStyle(chefTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chefTheme.textQuaternary)
            }
            .minimalCard(chefTheme)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    // MARK: - Recipe Thumbnail

    @ViewBuilder
    private func recipeThumbnail(_ recipe: Recipe, size: CGFloat, radius: CGFloat) -> some View {
        Color.clear
            .frame(width: size, height: size)
            .overlay {
                if let imageData = recipe.generatedDishImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    chefTheme.accent.opacity(0.10)
                        .overlay(
                            Image(systemName: "fork.knife")
                                .font(.system(size: size * 0.32))
                                .foregroundStyle(chefTheme.accent.opacity(0.4))
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    // MARK: - Challenges

    private var challengesSection: some View {
        Group {
            switch challengeService.dashboardState {
            case .loading:
                ProgressView()
                    .tint(chefTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            case .activeChallenges:
                if let challenge = challengeService.dashboardChallenges.first {
                    activeChallengeCard(challenge)
                }
            case .noActiveButHasPast:
                challengeEmptyStatePast
            case .noChallengesAtAll:
                challengeEmptyStateNone
            }
        }
    }

    private func activeChallengeCard(_ challenge: ChallengeDTO) -> some View {
        Button {
            if EntitlementManager.shared.hasAccess(to: .fullChallenges) {
                vm.showChallengeFeed = true
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    // Header
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.yellow)
                        Text("Cooking Challenges")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Text(challenge.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Start Challenge button
                    Text("Start Challenge")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(chefTheme.accentDeep)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.white)
                        )
                }

                Spacer()

                // Countdown
                if let countdown = challengeCountdown(challenge) {
                    VStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(countdown)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(chefTheme.heroGradient)
                    .shadow(color: chefTheme.accent.opacity(0.2), radius: 12, y: 6)
            )
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    private func challengeCountdown(_ challenge: ChallengeDTO) -> String? {
        guard let endsAtString = challenge.endsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var endsDate = formatter.date(from: endsAtString)
        if endsDate == nil {
            formatter.formatOptions = [.withInternetDateTime]
            endsDate = formatter.date(from: endsAtString)
        }
        guard let date = endsDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days <= 0 { return "Ends today" }
        if days == 1 { return "Ends in 1 day" }
        return "Ends in \(days) days"
    }

    private var challengeEmptyStatePast: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(chefTheme.accent.opacity(0.12))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22))
                        .foregroundStyle(chefTheme.accent)
                )

            VStack(spacing: 4) {
                Text("No active challenges")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(chefTheme.textSecondary)
                Text("Check back soon or browse past challenges")
                    .font(.system(size: 13))
                    .foregroundStyle(chefTheme.textTertiary)
            }

            Button {
                if EntitlementManager.shared.hasAccess(to: .fullChallenges) {
                    vm.showChallengeFeed = true
                } else {
                    showPaywall = true
                }
            } label: {
                Text("Browse Past Challenges")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(chefTheme.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .overlay(
                        Capsule()
                            .stroke(chefTheme.accent, lineWidth: 1)
                    )
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

    private var challengeEmptyStateNone: some View {
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

    // MARK: - Tasting Menu

    private var tastingMenuCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if authManager.isAuthenticated && !menuService.myMenus.isEmpty {
                HStack {
                    Text("Tasting Menus")
                        .font(.dsSection)
                        .foregroundStyle(chefTheme.textPrimary)
                    Spacer()
                    Button {
                        vm.showTastingMenus = true
                    } label: {
                        Text("See All")
                            .font(.dsBodyEmph)
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
                        .font(.dsCaption)
                        .foregroundStyle(chefTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chefTheme.textQuaternary)
            }
            .minimalCard(chefTheme)
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
                        .font(.dsBodyEmph)
                        .foregroundStyle(chefTheme.textPrimary)
                    Text(authManager.isAuthenticated
                         ? "Design a multi-course experience"
                         : "Sign in to create themed menus with friends")
                        .font(.dsCaption)
                        .foregroundStyle(chefTheme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chefTheme.textQuaternary)
            }
            .minimalCard(chefTheme)
        }
        .buttonStyle(PremiumCardButtonStyle())
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
