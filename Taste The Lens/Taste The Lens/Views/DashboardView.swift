import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "Dashboard")

struct DashboardView: View {
    @Bindable var vm: MainViewModel
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedRecipe: Recipe?

    private let authManager = AuthManager.shared
    private let challengeService = ChallengeService.shared
    private let menuService = TastingMenuService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                greetingSection
                heroCard
                challengesSection
                tastingMenuCard
                recentRecipesSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
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
        .task {
            await loadDashboardData()
        }
    }

    private func loadDashboardData() async {
        try? await challengeService.fetchChallenges(filter: .trending)
        if authManager.isAuthenticated {
            try? await menuService.fetchMyMenus()
        }
    }

    // MARK: - Greeting

    private var greetingSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    vm.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(Theme.buttonBg)
                        .clipShape(Circle())
                }

                Button {
                    vm.showSettings = true
                } label: {
                    if authManager.isAuthenticated {
                        initialsAvatar
                    } else {
                        Image(systemName: "person.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(Theme.buttonBg)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private var initialsAvatar: some View {
        let initials = String(displayName.prefix(1)).uppercased()
        return Text(initials)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Theme.darkBg)
            .frame(width: 40, height: 40)
            .background(Theme.gold)
            .clipShape(Circle())
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    private var displayName: String {
        if authManager.isAuthenticated {
            return authManager.displayName ?? "Chef"
        }
        return "Guest Chef"
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        Button {
            HapticManager.medium()
            vm.navigateToCamera()
        } label: {
            VStack(spacing: 20) {
                // Icon with gold glow background
                Circle()
                    .fill(Theme.gold.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.gold)
                    )

                VStack(spacing: 8) {
                    Text("Snap a Photo")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Capture inspiration and generate a recipe from ingredients, meals, or dishes.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }

                // Open Camera pill
                Text("Open Camera")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Theme.gold)
                    .clipShape(Capsule())
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.cardSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Theme.gold.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Theme.gold.opacity(0.08), radius: 30, x: 0, y: 12)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    // MARK: - Challenges

    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Cooking Challenges")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !challengeService.challenges.isEmpty {
                    Button {
                        vm.showChallengeFeed = true
                    } label: {
                        Text("See All")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.gold)
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
                .fill(Theme.gold.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.gold.opacity(0.5))
                )

            VStack(spacing: 4) {
                Text("No challenges yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                Text("Create a recipe to start one")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textQuaternary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }

    private func challengePreviewCard(_ challenge: ChallengeDTO) -> some View {
        Button {
            vm.showChallengeFeed = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Color.clear
                    .frame(width: 160, height: 100)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.gold.opacity(0.08))
                            .overlay(
                                Image(systemName: "flag.checkered")
                                    .font(.system(size: 28))
                                    .foregroundStyle(Theme.gold.opacity(0.25))
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(challenge.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .frame(width: 160, alignment: .leading)
            }
            .frame(width: 160)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    // MARK: - Tasting Menu

    private var tastingMenuCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if authManager.isAuthenticated && !menuService.myMenus.isEmpty {
                HStack {
                    Text("Tasting Menus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button {
                        vm.showTastingMenus = true
                    } label: {
                        Text("See All")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.gold)
                    }
                }

                ForEach(Array(menuService.myMenus.prefix(2))) { menu in
                    menuPreviewCard(menu)
                }
            }

            // Create menu action card
            createMenuCard
        }
    }

    private func menuPreviewCard(_ menu: TastingMenuDTO) -> some View {
        Button {
            vm.showTastingMenus = true
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Theme.gold.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "menucard")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.gold)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(menu.theme)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(menu.courseCount) courses · \(menu.status.capitalized)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textQuaternary)
            }
            .lightCard()
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
                    .fill(Theme.gold.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.gold)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Create a Tasting Menu")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(authManager.isAuthenticated
                         ? "Design a multi-course experience"
                         : "Sign in to create themed menus with friends")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textQuaternary)
            }
            .lightCard()
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    // MARK: - Recent Recipes

    private var recentRecipesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Recipes")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !recipes.isEmpty {
                    Button {
                        vm.showSavedRecipes = true
                    } label: {
                        Text("See All")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.gold)
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
        VStack(spacing: 12) {
            Circle()
                .fill(Theme.gold.opacity(0.1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "book.closed")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.gold.opacity(0.5))
                )

            VStack(spacing: 4) {
                Text("No recipes yet")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                Text("Snap a photo to generate your first dish")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textQuaternary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
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
                                .fill(Theme.gold.opacity(0.06))
                                .overlay(
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 28))
                                        .foregroundStyle(Theme.gold.opacity(0.2))
                                )
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.dishName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .frame(width: 160, alignment: .leading)

                    Text("AI Generated · \(recipe.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textQuaternary)
                }
            }
            .frame(width: 160)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }
}

// MARK: - Premium Button Style

/// Subtle scale + lift animation on press for all interactive cards.
struct PremiumCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}
