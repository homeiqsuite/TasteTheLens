import SwiftUI

struct AIReasoningView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var revealedItems = 0
    @State private var showTranslation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        whatISawSection
                        narrativeSection
                        colorPaletteSection
                        translationSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("AI Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                animateReveal()
            }
        }
        .presentationBackground(Theme.background)
    }

    // MARK: - What I Saw

    private var whatISawSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Inspiration image with floating tags
            ZStack(alignment: .topLeading) {
                if let uiImage = UIImage(data: recipe.inspirationImageData) {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .overlay {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.6)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        )
                }

                // Floating detected items
                if let analysis = recipe.sceneAnalysis {
                    VStack(alignment: .leading) {
                        Spacer()
                        FlowLayout(spacing: 6) {
                            ForEach(Array(analysis.detectedItems.enumerated()), id: \.offset) { index, item in
                                if index < revealedItems {
                                    Text(item)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Theme.accent1.opacity(0.5))
                                        .clipShape(Capsule())
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                        }
                        .padding(12)
                    }
                    .frame(height: 240)
                }
            }

            sectionTitle("What I Saw", icon: "eye")
        }
    }

    // MARK: - Narrative

    @ViewBuilder
    private var narrativeSection: some View {
        if let analysis = recipe.sceneAnalysis {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("My Interpretation", icon: "brain")

                let itemList = analysis.detectedItems.prefix(3).joined(separator: ", ")
                let approachName: String = {
                    switch analysis.approach {
                    case "ingredient-driven": return "ingredient-driven"
                    case "hybrid": return "hybrid"
                    default: return "visual translation"
                    }
                }()

                Text("I noticed **\(itemList)** in what appears to be \(analysis.setting.lowercased()). Using a **\(approachName)** approach, I translated these elements into \"\(recipe.dishName).\"")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(4)

                if !analysis.detectedText.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.primary.opacity(0.6))
                        Text("Text spotted: \(analysis.detectedText.joined(separator: ", "))")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .lightCard()
        }
    }

    // MARK: - Color Palette

    @ViewBuilder
    private var colorPaletteSection: some View {
        if !recipe.colorPalette.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Color Extraction", icon: "paintpalette")

                HStack(spacing: 0) {
                    ForEach(recipe.colorPalette, id: \.self) { hex in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: hex))
                                .frame(height: 48)

                            Text(hex)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .lightCard()
        }
    }

    // MARK: - Translation

    private var translationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("How I Translated It", icon: "arrow.triangle.swap")

            ForEach(Array(recipe.translationMatrix.enumerated()), id: \.offset) { index, item in
                VStack(spacing: 8) {
                    // Visual element
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.accent1.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text(item.visual)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.accent1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Arrow
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.primary.opacity(0.5))

                    // Culinary equivalent
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.accent2.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Text(item.culinary)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.accent2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(showTranslation ? 1 : 0)
                .offset(y: showTranslation ? 0 : 20)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.15),
                    value: showTranslation
                )
            }
        }
        .lightCard()
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.primary)
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.primary)
        }
    }

    private func animateReveal() {
        guard let analysis = recipe.sceneAnalysis else {
            showTranslation = true
            return
        }

        // Reveal detected items one by one
        for i in 0...analysis.detectedItems.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    revealedItems = i
                }
            }
        }

        // Then show translations
        let delay = Double(analysis.detectedItems.count) * 0.2 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            showTranslation = true
        }
    }
}
