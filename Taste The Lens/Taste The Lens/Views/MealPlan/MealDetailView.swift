import SwiftUI
import SwiftData

/// Full recipe for a single planned meal: hero image, research provenance,
/// nutrition, components, cooking steps, and sources.
struct MealDetailView: View {
    @Bindable var meal: PlannedMeal
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedChef") private var selectedChef = "default"

    @State private var isPreparing = false
    @State private var shareError: String?

    private var chefTheme: ChefTheme {
        ChefPersonality(rawValue: selectedChef)?.theme ?? ChefPersonality.defaultChef.theme
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let image = meal.generatedImage {
                    Color.clear
                        .frame(height: 220)
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
                }

                header
                if !meal.researchNotes.isEmpty { researchCard }
                if let nutrition = meal.nutrition { nutritionCard(nutrition) }
                componentsCard
                stepsCard
                if !meal.sources.isEmpty { sourcesCard }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .background(chefTheme.dashboardBg.ignoresSafeArea())
        .navigationTitle(meal.mealType)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        meal.isFavorite.toggle()
                        try? modelContext.save()
                        HapticManager.light()
                    } label: {
                        Image(systemName: meal.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(meal.isFavorite ? .pink : chefTheme.accent)
                    }
                    Menu {
                        Button { exportPDF() } label: { Label("Export PDF", systemImage: "doc.richtext") }
                        Button { Task { await shareLink() } } label: { Label("Share link", systemImage: "link") }
                    } label: {
                        Image(systemName: "square.and.arrow.up").foregroundStyle(chefTheme.accent)
                    }
                    .disabled(isPreparing)
                }
            }
        }
        .overlay { if isPreparing { preparingOverlay } }
        .alert("Couldn't share", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(shareError ?? "") }
    }

    private var preparingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Preparing link…").font(.dsCaption).foregroundStyle(.white)
            }
        }
    }

    private func exportPDF() {
        let data = PDFExporter.generateMealPDF(for: meal)
        SharePresenter.presentPDF(data, fileName: meal.dishName)
    }

    private func shareLink() async {
        guard AuthManager.shared.isAuthenticated else { shareError = "Sign in to share a link."; return }
        guard meal.plan != nil else { shareError = "This meal can't be shared on its own."; return }
        isPreparing = true
        defer { isPreparing = false }
        do {
            let url = try await SyncManager.shared.shareLinkForMeal(meal)
            SharePresenter.present([meal.dishName, url])
        } catch {
            shareError = "Couldn't create a link. Please try again."
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meal.dishName)
                .font(.dsTitle)
                .foregroundStyle(chefTheme.textPrimary)
            Text(meal.mealDescription)
                .font(.dsBody)
                .foregroundStyle(chefTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                if let prep = meal.prepTime { metaPill(icon: "timer", text: "Prep \(prep)") }
                if let cook = meal.cookTime { metaPill(icon: "flame", text: "Cook \(cook)") }
                if let diff = meal.difficulty { metaPill(icon: "chart.bar", text: diff) }
            }
        }
    }

    private func metaPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text).font(.dsCaption)
        }
        .foregroundStyle(chefTheme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(chefTheme.accent.opacity(0.10)))
    }

    private var researchCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Why this meal", systemImage: "sparkle.magnifyingglass")
                .font(.dsBodyEmph)
                .foregroundStyle(chefTheme.accent)
            Text(meal.researchNotes)
                .font(.dsBody)
                .foregroundStyle(chefTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .minimalCard(chefTheme)
    }

    private func nutritionCard(_ n: NutritionInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Nutrition (per serving)")
            HStack(spacing: 10) {
                macro("\(n.calories)", "cal")
                macro("\(n.protein)g", "protein")
                macro("\(n.carbs)g", "carbs")
                macro("\(n.fat)g", "fat")
            }
        }
        .minimalCard(chefTheme)
    }

    private func macro(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.dsBodyEmph)
                .foregroundStyle(chefTheme.textPrimary)
            Text(label)
                .font(.dsMicro)
                .foregroundStyle(chefTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var componentsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Ingredients")
            ForEach(Array(meal.components.enumerated()), id: \.offset) { _, component in
                VStack(alignment: .leading, spacing: 6) {
                    Text(component.name)
                        .font(.dsBodyEmph)
                        .foregroundStyle(chefTheme.textPrimary)
                    ForEach(component.ingredients, id: \.self) { ingredient in
                        HStack(alignment: .top, spacing: 8) {
                            Circle().fill(chefTheme.accent).frame(width: 5, height: 5).padding(.top, 6)
                            Text(ingredient)
                                .font(.dsBody)
                                .foregroundStyle(chefTheme.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .minimalCard(chefTheme)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Cooking Steps")
            ForEach(Array(meal.cookingSteps.enumerated()), id: \.offset) { index, step in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.dsBodyEmph)
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(chefTheme.accent))
                        Text(step.instruction)
                            .font(.dsBody)
                            .foregroundStyle(chefTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let tip = step.tip, !tip.isEmpty {
                        Text("Tip: \(tip)")
                            .font(.dsCaption)
                            .foregroundStyle(chefTheme.textTertiary)
                            .padding(.leading, 34)
                    }
                }
            }
        }
        .minimalCard(chefTheme)
    }

    private var sourcesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Sources")
            ForEach(meal.sources, id: \.self) { source in
                if let url = URL(string: source) {
                    Link(destination: url) {
                        Text(source)
                            .font(.dsCaption)
                            .foregroundStyle(chefTheme.accent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                } else {
                    Text(source)
                        .font(.dsCaption)
                        .foregroundStyle(chefTheme.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .minimalCard(chefTheme)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.dsSection)
            .foregroundStyle(chefTheme.textPrimary)
    }
}
