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
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
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
                Theme.background.ignoresSafeArea()

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
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
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
                            .foregroundStyle(Theme.primary)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewMode = viewMode == .grid ? .list : .grid
                        }
                    } label: {
                        Image(systemName: viewMode == .grid ? "list.bullet" : "square.grid.2x2")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.primary)
                    }
                    .accessibilityLabel(viewMode == .grid ? "Switch to list view" : "Switch to grid view")
                }
            }
            .sheet(isPresented: $showSignIn) {
                SignInView()
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
            .preferredColorScheme(.light)
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
                SavedRecipeCard(recipe: recipe)
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
        .padding(16)
    }

    // MARK: - List View

    private var listView: some View {
        LazyVStack(spacing: 8) {
            ForEach(filteredRecipes) { recipe in
                SavedRecipeListRow(recipe: recipe)
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
                        .tint(Theme.primary)
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Auth Banner

    private var authBanner: some View {
        Button { showSignIn = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to sync your recipes")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Access your menu from any device")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textQuaternary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.primary.opacity(0.15), lineWidth: 0.5)
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
                .foregroundStyle(Theme.textQuaternary)
            Text("Your menu is empty")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            Text("Capture a photo to create your first dish.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textQuaternary)

            Button {
                dismiss()
            } label: {
                Label("Take a Photo", systemImage: "camera")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.primary)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func deleteRecipe(_ recipe: Recipe) {
        withAnimation {
            modelContext.delete(recipe)
            try? modelContext.save()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            if let imageData = recipe.generatedDishImageData,
               let uiImage = UIImage(data: imageData) {
                Color.clear
                    .frame(height: 140)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.divider)
                    .frame(height: 140)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(Theme.textQuaternary)
                    )
            }

            Text(recipe.dishName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)

            HStack(spacing: 4) {
                Text(recipe.createdAt, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)

                if recipe.syncStatus == "synced" {
                    Image(systemName: "checkmark.icloud")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textQuaternary)
                }
            }
        }
        .lightCard(cornerRadius: 12)
    }
}

// MARK: - List Row

struct SavedRecipeListRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageData = recipe.generatedDishImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.divider)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textQuaternary)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.dishName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(recipe.createdAt, style: .date)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)

                    if recipe.syncStatus == "synced" {
                        Image(systemName: "checkmark.icloud")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textQuaternary)
                    } else if recipe.syncStatus == "syncing" {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textQuaternary)
                    } else if recipe.syncStatus == "failed" {
                        Image(systemName: "exclamationmark.icloud")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.5))
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textQuaternary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Theme.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
        )
        .padding(.vertical, 2)
    }
}
