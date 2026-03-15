import SwiftUI
import SwiftData

struct RecipeCardView: View {
    let recipe: Recipe
    @Environment(\.modelContext) private var modelContext
    @State private var exportImage: UIImage?
    @State private var heroAppeared = false
    @State private var isSaved = false

    private let gold = Color(red: 0.788, green: 0.659, blue: 0.298) // #C9A84C
    private let cyan = Color(red: 0.392, green: 0.824, blue: 1.0)   // #64D2FF
    private let coral = Color(red: 1.0, green: 0.42, blue: 0.42)    // #FF6B6B
    private let bg = Color(red: 0.051, green: 0.051, blue: 0.059)   // #0D0D0F

    var body: some View {
        ZStack(alignment: .bottom) {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    heroImageSection
                    sceneAnalysisSection
                    dishHeaderSection
                    translationMatrixSection
                    componentsSection
                    cookingInstructionsSection
                    platingSection
                    pairingSection
                    Spacer().frame(height: 80) // Space for bottom bar
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
            }
            .clipped()

            actionBar
        }
        .onAppear {
            renderExportImage()
        }
    }

    // MARK: - Hero Image

    private var heroImageSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Generated dish image
            if let imageData = recipe.generatedDishImageData,
               let uiImage = UIImage(data: imageData) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .offset(y: heroAppeared ? 0 : -40)
                    .opacity(heroAppeared ? 1 : 0)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7), value: heroAppeared)
            }

            // Source thumbnail PIP
            if let uiImage = UIImage(data: recipe.inspirationImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 4)
                    .padding(12)
            }
        }
        .onAppear { heroAppeared = true }
    }

    // MARK: - Scene Analysis

    @ViewBuilder
    private var sceneAnalysisSection: some View {
        if let analysis = recipe.sceneAnalysis, !analysis.detectedItems.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(cyan)
                    Text("WHAT OUR CHEF NOTICED")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(cyan)
                }

                FlowLayout(spacing: 6) {
                    ForEach(analysis.detectedItems, id: \.self) { item in
                        Text(item)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(cyan.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text(approachLabel(analysis.approach))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(approachColor(analysis.approach))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(approachColor(analysis.approach).opacity(0.12))
                        .clipShape(Capsule())

                    Text(analysis.setting)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .glassCard()
        }
    }

    private func approachLabel(_ approach: String) -> String {
        switch approach {
        case "ingredient-driven": return "Built from real ingredients"
        case "hybrid": return "Ingredients + visual inspiration"
        default: return "Inspired by visual elements"
        }
    }

    private func approachColor(_ approach: String) -> Color {
        switch approach {
        case "ingredient-driven": return coral
        case "hybrid": return gold
        default: return cyan
        }
    }

    // MARK: - Dish Header

    private var dishHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.dishName)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(gold)

            Text(recipe.recipeDescription)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.white.opacity(0.8))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Translation Matrix

    private var translationMatrixSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Translation Matrix")

            ForEach(recipe.translationMatrix, id: \.self) { item in
                HStack(alignment: .top, spacing: 12) {
                    Text(item.visual)
                        .font(.system(size: 14))
                        .foregroundStyle(cyan)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))

                    Text(item.culinary)
                        .font(.system(size: 14))
                        .foregroundStyle(coral)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)

                if item != recipe.translationMatrix.last {
                    Divider().background(Color.white.opacity(0.1))
                }
            }
        }
        .glassCard()
    }

    // MARK: - Components

    private var componentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Components")

            ForEach(recipe.components, id: \.self) { component in
                ComponentCard(component: component, gold: gold)
            }
        }
        .glassCard()
    }

    // MARK: - Cooking Instructions

    @ViewBuilder
    private var cookingInstructionsSection: some View {
        if !recipe.cookingInstructions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("How to Make It")

                ForEach(Array(recipe.cookingInstructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(gold)
                            .frame(width: 28)

                        Text(step)
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineSpacing(3)
                    }
                }
            }
            .glassCard()
        }
    }

    // MARK: - Plating

    private var platingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Plating")

            ForEach(Array(recipe.platingSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(gold)
                        .frame(width: 28)

                    Text(step)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(3)
                }
            }
        }
        .glassCard()
    }

    // MARK: - Pairing

    private var pairingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Sommelier Pairing")

            pairingRow(icon: "wineglass", title: "Wine", text: recipe.sommelierPairing.wine)
            pairingRow(icon: "cup.and.saucer", title: "Cocktail", text: recipe.sommelierPairing.cocktail)
            pairingRow(icon: "leaf", title: "Non-Alcoholic", text: recipe.sommelierPairing.nonalcoholic)
        }
        .glassCard()
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 16) {
            Button {
                shareRecipe()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                saveRecipe()
            } label: {
                Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "checkmark" : "bookmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSaved ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSaved ? gold : Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            bg.opacity(0.95)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .semibold))
            .tracking(1)
            .foregroundStyle(gold)
    }

    private func pairingRow(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(gold)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineSpacing(2)
            }
        }
    }

    private func saveRecipe() {
        guard !isSaved else { return }
        modelContext.insert(recipe)
        try? modelContext.save()
        isSaved = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func renderExportImage() {
        let renderer = ImageRenderer(content:
            SideBySideExportView(recipe: recipe)
                .frame(width: 1080, height: 1080)
        )
        renderer.scale = 3.0
        exportImage = renderer.uiImage
    }

    private func shareRecipe() {
        if exportImage == nil {
            renderExportImage()
        }
        guard let exportImage else { return }
        presentShareSheet(image: exportImage)
    }

    private func presentShareSheet(image: UIImage) {
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else { return }
        // Walk to the topmost presented controller
        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        activityVC.popoverPresentationController?.sourceView = presenter.view
        presenter.present(activityVC, animated: true)
    }
}

// MARK: - Component Card

struct ComponentCard: View {
    let component: RecipeComponent
    let gold: Color
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(component.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Ingredients
                    FlowLayout(spacing: 6) {
                        ForEach(component.ingredients, id: \.self) { ingredient in
                            Text(ingredient)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Capsule())
                        }
                    }

                    // Method
                    Text(component.method)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineSpacing(3)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }
}

// Simple flow layout for ingredient tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalHeight = currentY + lineHeight
        }

        return (positions, CGSize(width: maxWidth, height: totalHeight))
    }
}

// MARK: - Preview

#Preview {
    let sampleImage: UIImage = {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400))
        return renderer.image { ctx in
            UIColor.darkGray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 100, y: 100, width: 200, height: 200))
        }
    }()
    let imageData = sampleImage.jpegData(compressionQuality: 0.8)!

    let recipe = Recipe(
        dishName: "Syntax of Zest: A Modern Scallop & Citrus Composition",
        recipeDescription: "Inspired by the vibrant energy and precise structure of a digital workspace, this dish translates the sharp contrasts of glowing screens and organized code into a symphony of flavors.",
        inspirationImageData: imageData,
        generatedDishImageData: imageData,
        generatedDishImageURL: "",
        translationMatrix: [
            TranslationItem(visual: "Dominant orange hue from Gatorade cap and screen element (#FF8C00)", culinary: "Roasted Carrot & Orange Zest Puree — sweet, earthy, vibrant"),
            TranslationItem(visual: "Bright lime green from Gatorade glow (#00FF00)", culinary: "Vibrant Lime & Chive Oil — fresh, zesty, herbaceous"),
            TranslationItem(visual: "Dark grey/black background of desk mat", culinary: "Black Sesame Tuiles — savory, nutty, dramatic"),
        ],
        components: [
            RecipeComponent(name: "Seared Scallops", ingredients: ["6 large scallops", "2 tbsp butter", "Salt & pepper"], method: "Pat scallops dry. Season generously. Sear in hot butter for 2 minutes per side until golden."),
            RecipeComponent(name: "Citrus Puree", ingredients: ["3 carrots", "1 orange, zested & juiced", "1 tbsp honey"], method: "Roast carrots until caramelized. Blend with orange juice, zest, and honey until smooth."),
        ],
        cookingInstructions: [
            "Prepare the citrus puree and let it cool slightly.",
            "Sear the scallops in a hot pan with butter until golden on each side.",
            "Drizzle the chive oil around the plate in a free-form pattern.",
        ],
        platingSteps: [
            "Spoon citrus puree in a swoosh across the center of a dark plate.",
            "Place scallops atop the puree.",
            "Garnish with micro herbs and edible flowers.",
        ],
        sommelierPairing: SommelierPairing(
            wine: "Sancerre — crisp, mineral, citrus-forward",
            cocktail: "Yuzu Gimlet with thyme",
            nonalcoholic: "Sparkling water with orange blossom and rosemary"
        ),
        sceneAnalysis: SceneAnalysis(
            detectedItems: ["Gatorade bottle", "desk lamp", "mechanical keyboard", "monitor with code editor", "dark desk mat"],
            detectedText: ["Gatorade"],
            setting: "Developer desk setup, warm ambient lighting",
            approach: "visual-translation"
        ),
        claudeRawResponse: ""
    )

    NavigationStack {
        RecipeCardView(recipe: recipe)
    }
    .modelContainer(for: Recipe.self, inMemory: true)
}
