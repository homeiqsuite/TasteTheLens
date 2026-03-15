import SwiftUI
import SwiftData

struct SavedRecipesView: View {
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRecipe: Recipe?

    private let bg = Color(red: 0.051, green: 0.051, blue: 0.059)
    private let gold = Color(red: 0.788, green: 0.659, blue: 0.298)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                if recipes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(recipes) { recipe in
                                SavedRecipeCard(recipe: recipe)
                                    .onTapGesture {
                                        selectedRecipe = recipe
                                    }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("My Menu")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(gold)
                }
            }
            .sheet(item: $selectedRecipe) { recipe in
                NavigationStack {
                    RecipeCardView(recipe: recipe)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Done") { selectedRecipe = nil }
                                    .foregroundStyle(gold)
                            }
                        }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.2))
            Text("No saved recipes yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text("Capture a photo to create your first dish.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))
        }
    }
}

struct SavedRecipeCard: View {
    let recipe: Recipe
    private let gold = Color(red: 0.788, green: 0.659, blue: 0.298)

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
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 140)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.2))
                    )
            }

            Text(recipe.dishName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(recipe.createdAt, style: .date)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.4))
        }
        .glassCard(cornerRadius: 12, opacity: 0.06)
    }
}
