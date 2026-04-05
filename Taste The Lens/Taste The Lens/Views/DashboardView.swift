import SwiftUI
import SwiftData
import PhotosUI
import os

private let logger = makeLogger(category: "Dashboard")

struct DashboardView: View {
    @Bindable var vm: MainViewModel
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedRecipe: Recipe?
    @State private var showChefPicker = false
    @State private var showPaywall = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false

    // Hero card animations
    @State private var gradientBreathing = false
    @State private var cardAppeared = false
    @State private var iconAppeared = false
    @State private var textAppeared = false
    @State private var ctaAppeared = false
    @AppStorage("selectedChef") private var selectedChef = "default"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let authManager = AuthManager.shared
    private let challengeService = ChallengeService.shared
    private let menuService = TastingMenuService.shared
    private let impactService = CommunityImpactService.shared

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

    private var creditBadgeText: String {
        let credits = UsageTracker.shared.totalAvailableCredits
        let approxRecipes = max(credits / 5, 0)
        return "\(credits) credits · ~\(approxRecipes) recipes left"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                greetingSection
                statsBar
                heroCard
                chefModeCard
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
            .padding(.bottom, 40)
        }
        .background(chefTheme.dashboardBg.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.4), value: selectedChef)
        .refreshable {
            await refreshDashboard()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    vm.handlePhotoCaptured(image)
                }
                selectedPhotoItem = nil
            }
        }
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
            ChefModeView(context: .defaultChef)
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
            Text("\(greetingText), \(displayName)")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(chefTheme.textPrimary)

            Spacer()

            HStack(spacing: 10) {
                Button {
                    vm.showSettings = true
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(chefTheme.accent)
                        .frame(width: 40, height: 40)
                        .background(chefTheme.accent.opacity(0.12))
                        .clipShape(Circle())
                }

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

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 0) {
            // Cooking Streak
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cooking Streak")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(chefTheme.textTertiary)
                    Text("\(cookingStreak) days")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(chefTheme.accent)
                }
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(chefTheme.cardBorder)
                .frame(width: 1, height: 36)

            // Recipes Created
            HStack(spacing: 10) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Recipes Created")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(chefTheme.textTertiary)
                    Text("\(recipesThisWeek) this week")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(chefTheme.accent)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .themedCard(chefTheme)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            // Breathing gradient background
            RoundedRectangle(cornerRadius: 28)
                .fill(chefTheme.heroGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.clear,
                                    Color.white.opacity(0.06),
                                ],
                                startPoint: gradientBreathing ? .topLeading : .bottomTrailing,
                                endPoint: gradientBreathing ? .bottomTrailing : .topLeading
                            )
                        )
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 6.0).repeatForever(autoreverses: true),
                            value: gradientBreathing
                        )
                )

            // Sparkle/glow overlay
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.03),
                            Color.clear,
                        ],
                        center: .topTrailing,
                        startRadius: 20,
                        endRadius: 250
                    )
                )

            VStack(alignment: .leading, spacing: 16) {
                // Credit badge
                Text(creditBadgeText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.2))
                    )
                    .opacity(textAppeared ? 1 : 0)

                // Main content row
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What are you cooking today?")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                        Text("Turn any ingredients or dish into a recipe in seconds.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineSpacing(2)
                    }
                    .opacity(textAppeared ? 1 : 0)
                    .offset(y: textAppeared ? 0 : 8)

                    Spacer()

                    // Camera icon
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white)
                        )
                        .opacity(iconAppeared ? 1 : 0)
                        .offset(y: iconAppeared ? 0 : -10)
                }

                // Action buttons
                HStack(spacing: 10) {
                    // Upload Image
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Label("Upload Image", systemImage: "photo.on.rectangle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.25))
                            )
                    }

                    Spacer()

                    // Snap a Photo
                    Button {
                        HapticManager.medium()
                        vm.navigateToCamera()
                    } label: {
                        Label("Snap a Photo", systemImage: "camera.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(chefTheme.accentDeep)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                            )
                    }
                }
                .opacity(ctaAppeared ? 1 : 0)
                .offset(y: ctaAppeared ? 0 : 12)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .shadow(color: chefTheme.accent.opacity(0.35), radius: 20, y: 10)
        .scaleEffect(cardAppeared ? 1.0 : 0.95)
        .opacity(cardAppeared ? 1 : 0)
        .onAppear {
            gradientBreathing = !reduceMotion
            startEntranceAnimation()
        }
    }

    private func startEntranceAnimation() {
        if reduceMotion {
            cardAppeared = true
            iconAppeared = true
            textAppeared = true
            ctaAppeared = true
            return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            cardAppeared = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) {
            iconAppeared = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            textAppeared = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.45)) {
            ctaAppeared = true
        }
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

                HStack(spacing: 4) {
                    Text("Change Mode")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(chefTheme.accent)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(chefTheme.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .overlay(
                    Capsule()
                        .stroke(chefTheme.accent, lineWidth: 1)
                )
            }
            .themedCard(chefTheme)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    // MARK: - Continue Cooking

    private func continueCookingSection(_ lastRecipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Continue Cooking")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(chefTheme.textPrimary)
                Spacer()
                Button {
                    vm.showSavedRecipes = true
                } label: {
                    Text("See All")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(chefTheme.accent)
                }
            }

            Button {
                selectedRecipe = lastRecipe
            } label: {
                HStack(spacing: 14) {
                    // Recipe thumbnail with badge
                    Color.clear
                        .frame(width: 140, height: 110)
                        .overlay {
                            if let imageData = lastRecipe.generatedDishImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(chefTheme.accent.opacity(0.08))
                                    .overlay(
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 28))
                                            .foregroundStyle(chefTheme.accent.opacity(0.3))
                                    )
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(alignment: .topLeading) {
                            // Last Recipe badge
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("Last Recipe")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.5))
                            )
                            .padding(8)
                        }

                    // Recipe info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lastRecipe.dishName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(chefTheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Text("Generated · \(lastRecipe.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(chefTheme.textTertiary)

                        Spacer()

                        HStack(spacing: 4) {
                            Text("Continue")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(chefTheme.accent)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(chefTheme.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .themedCard(chefTheme)
            }
            .buttonStyle(PremiumCardButtonStyle())
        }
    }

    // MARK: - My Recipes

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
                ZStack {
                    Circle()
                        .fill(chefTheme.accent.opacity(0.10))
                        .frame(width: 72, height: 72)

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
                // Dish image thumbnail with heart overlay
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
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(chefTheme.accent.opacity(0.7))
                            )
                            .padding(6)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.dishName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(chefTheme.textPrimary)
                        .lineLimit(2)
                        .frame(width: 160, alignment: .leading)

                    Text("Generated · \(recipe.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(chefTheme.textQuaternary)
                }
            }
            .frame(width: 160)
        }
        .buttonStyle(PremiumCardButtonStyle())
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
