import SwiftUI
import SwiftData

enum ViewMode: String {
    case grid, list
}

enum SortOrder: String, CaseIterable {
    case newest = "Newest"
    case oldest = "Oldest"
    case alphabetical = "A-Z"
}

struct SavedRecipesView: View {
    @Bindable var vm: MainViewModel
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedChef") private var selectedChef = "default"
    @State private var selectedRecipe: Recipe?
    @State private var showSignIn = false
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .grid
    @State private var sortOrder: SortOrder = .newest
    @State private var recipeToDelete: Recipe?
    @State private var showDeleteConfirmation = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var chefTheme: ChefTheme {
        let chef = ChefPersonality(rawValue: selectedChef) ?? .defaultChef
        return chef.theme
    }

    private var filteredRecipes: [Recipe] {
        let filtered: [Recipe]
        if searchText.isEmpty {
            filtered = Array(recipes)
        } else {
            let query = searchText
            filtered = recipes.filter {
                $0.dishName.localizedCaseInsensitiveContains(query)
            }
        }

        switch sortOrder {
        case .newest:
            // @Query already sorts by createdAt descending
            return filtered
        case .oldest:
            return filtered.reversed()
        case .alphabetical:
            return filtered.sorted { $0.dishName.localizedCaseInsensitiveCompare($1.dishName) == .orderedAscending }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                chefTheme.dashboardBg.ignoresSafeArea()

                if recipes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Auth banner for guests with 3+ recipes
                            if recipes.count >= 3 && !AuthManager.shared.isAuthenticated {
                                authBanner
                            }

                            if viewMode == .grid {
                                gridView
                            } else {
                                listView
                            }
                        }
                        .padding(.bottom, DS.tabBarClearance)
                    }
                }
            }
            .navigationTitle("My Menu")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search dishes")
            .refreshable {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        await SyncManager.shared.syncAll(modelContext: modelContext)
                    }
                    group.addTask {
                        try? await Task.sleep(for: .seconds(15))
                    }
                    // Return as soon as either sync completes or timeout fires
                    await group.next()
                    group.cancelAll()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button {
                                sortOrder = order
                            } label: {
                                HStack {
                                    Text(order.rawValue)
                                    if sortOrder == order {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14))
                            .foregroundStyle(chefTheme.accent)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = viewMode == .grid ? .list : .grid
                        }
                    } label: {
                        Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                            .font(.system(size: 14))
                            .foregroundStyle(chefTheme.accent)
                    }
                    .accessibilityLabel(viewMode == .grid ? "Switch to list view" : "Switch to grid view")
                }
            }
            .sheet(isPresented: $showSignIn) {
                SignInView()
            }
            .sheet(item: $selectedRecipe) { recipe in
                NavigationStack {
                    RecipeCardView(recipe: recipe, onDismiss: { selectedRecipe = nil })
                }
            }
            .alert("Delete Recipe", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { recipeToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let recipe = recipeToDelete {
                        deleteRecipe(recipe)
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(recipeToDelete?.dishName ?? "this recipe")\"?")
            }
        }
    }

    // MARK: - Grid View

    private var gridView: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filteredRecipes) { recipe in
                SavedRecipeCard(recipe: recipe, theme: chefTheme)
                    .onTapGesture {
                        selectedRecipe = recipe
                    }
                    .contextMenu {
                        Button {
                            shareRecipe(recipe)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            recipeToDelete = recipe
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - List View

    private var listView: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredRecipes) { recipe in
                SavedRecipeListRow(recipe: recipe, theme: chefTheme)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedRecipe = recipe
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            recipeToDelete = recipe
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            shareRecipe(recipe)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(chefTheme.accent)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Auth Banner

    private var authBanner: some View {
        Button { showSignIn = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 15))
                    .foregroundStyle(chefTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to sync your recipes")
                        .font(.dsBodyEmph)
                        .foregroundStyle(chefTheme.textPrimary)
                    Text("Access your menu from any device")
                        .font(.dsCaption)
                        .foregroundStyle(chefTheme.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chefTheme.textQuaternary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                    .fill(chefTheme.accent.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                            .strokeBorder(chefTheme.accent.opacity(0.18), lineWidth: DS.Stroke.hairline)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(chefTheme.textQuaternary)
            Text("Your menu is empty")
                .font(.dsSection)
                .foregroundStyle(chefTheme.textSecondary)
            Text("Capture a photo to create your first dish.")
                .font(.dsBody)
                .foregroundStyle(chefTheme.textTertiary)

            Button {
                HapticManager.medium()
                vm.navigateToCamera()
            } label: {
                Label("Take a Photo", systemImage: "camera.fill")
                    .font(.dsBodyEmph)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(chefTheme.accent))
            }
            .padding(.top, 8)
        }
        .padding(.bottom, DS.tabBarClearance)
    }

    // MARK: - Actions

    private func deleteRecipe(_ recipe: Recipe) {
        withAnimation {
            Task {
                await SyncManager.shared.deleteRecipeRemotely(recipe, modelContext: modelContext)
            }
        }
        recipeToDelete = nil
    }

    private func shareRecipe(_ recipe: Recipe) {
        let renderer = ImageRenderer(content:
            SideBySideExportView(recipe: recipe)
                .frame(width: 1080, height: 1080)
        )
        renderer.scale = 3.0
        guard let image = renderer.uiImage else { return }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else { return }
        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        activityVC.popoverPresentationController?.sourceView = presenter.view
        presenter.present(activityVC, animated: true)
    }
}

// MARK: - Grid Card

struct SavedRecipeCard: View {
    let recipe: Recipe
    let theme: ChefTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.clear
                .frame(height: 130)
                .overlay {
                    if let imageData = recipe.generatedDishImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        theme.accent.opacity(0.10)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 26))
                                    .foregroundStyle(theme.accent.opacity(0.4))
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))

            Text(recipe.dishName)
                .font(.dsBodyEmph)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)

            HStack(spacing: 4) {
                Text(recipe.createdAt, style: .date)
                    .font(.dsCaption)
                    .foregroundStyle(theme.textTertiary)

                if recipe.syncStatus == "synced" {
                    Image(systemName: "checkmark.icloud")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textQuaternary)
                }
            }
        }
        .minimalCard(theme, radius: DS.Radius.tile, padding: EdgeInsets(top: 10, leading: 10, bottom: 12, trailing: 10))
    }
}

// MARK: - List Row

struct SavedRecipeListRow: View {
    let recipe: Recipe
    let theme: ChefTheme

    var body: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 60, height: 60)
                .overlay {
                    if let imageData = recipe.generatedDishImageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        theme.accent.opacity(0.10)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 18))
                                    .foregroundStyle(theme.accent.opacity(0.4))
                            )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.dishName)
                    .font(.dsBodyEmph)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(recipe.createdAt, style: .date)
                        .font(.dsCaption)
                        .foregroundStyle(theme.textTertiary)

                    if recipe.syncStatus == "synced" {
                        Image(systemName: "checkmark.icloud")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textQuaternary)
                    } else if recipe.syncStatus == "syncing" {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textQuaternary)
                    } else if recipe.syncStatus == "failed" {
                        Image(systemName: "exclamationmark.icloud")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.5))
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textQuaternary)
        }
        .minimalCard(theme, radius: DS.Radius.tile, padding: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 14))
    }
}
