import SwiftUI
import SwiftData

/// Week overview for a generated meal plan. Images are opt-in and *selective*:
/// the user enters a selection mode, picks exactly the recipes they want
/// illustrated, and only those are generated (1 credit each) — they don't have
/// to pay for the whole bundle. Generation is progressive and backgroundable.
struct MealPlanView: View {
    @Bindable var plan: MealPlan
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedChef") private var selectedChef = "default"

    @State private var pipeline = MealPlanPipeline()
    @State private var selectionMode = false
    @State private var selectedMealIDs: Set<UUID> = []
    /// The set the user asked to generate — used to resume after backgrounding.
    @State private var queuedMealIDs: Set<UUID> = []
    @State private var autoImagesRequested = false
    @State private var isPreparingShare = false
    @State private var shareError: String?
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    private var chefTheme: ChefTheme {
        ChefPersonality(rawValue: plan.chefPersonality ?? selectedChef)?.theme ?? ChefPersonality.defaultChef.theme
    }

    private var selectableMeals: [PlannedMeal] {
        plan.meals.filter { !$0.imageGenerated && !$0.imageGenerationPrompt.isEmpty }
    }
    private var pendingImageCount: Int { selectableMeals.count }
    private var selectedCount: Int { selectedMealIDs.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard
                groceryListLink
                imagesCard
                ForEach(plan.mealsByDay, id: \.day) { group in
                    daySection(day: group.day, meals: group.meals)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .background(chefTheme.dashboardBg.ignoresSafeArea())
        .navigationTitle(plan.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        plan.isFavorite.toggle()
                        try? modelContext.save()
                        HapticManager.light()
                    } label: {
                        Image(systemName: plan.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(plan.isFavorite ? .pink : chefTheme.accent)
                    }
                    Menu {
                        Button { exportPDF() } label: { Label("Export plan PDF", systemImage: "doc.richtext") }
                        Button { Task { await sharePlanLink() } } label: { Label("Share plan link", systemImage: "link") }
                        Divider()
                        Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete plan", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundStyle(chefTheme.accent)
                    }
                    .disabled(isPreparingShare || selectionMode)
                }
            }
        }
        .overlay {
            if isPreparingShare {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text("Preparing link…").font(.dsCaption).foregroundStyle(.white)
                    }
                }
            }
        }
        .alert("Couldn't share", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(shareError ?? "") }
        .alert("Delete this plan?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await deletePlan() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the plan and its meals from your library. Any shared links will stop working.")
        }
        .safeAreaInset(edge: .bottom) {
            if selectionMode { selectionBar }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, autoImagesRequested, !pipeline.isGeneratingImages {
                let resume = selectableMeals.filter { queuedMealIDs.contains($0.id) }
                if !resume.isEmpty {
                    Task { await pipeline.generateImages(for: resume, modelContext: modelContext) }
                }
            }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 16) {
            summaryStat(value: "\(plan.daysCount)", label: "Days")
            divider
            summaryStat(value: "\(plan.totalMealCount)", label: "Meals")
            divider
            summaryStat(value: "\(plan.groceryList.count)", label: "Items")
        }
        .frame(maxWidth: .infinity)
        .minimalCard(chefTheme)
    }

    private func summaryStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.dsMetric).foregroundStyle(chefTheme.textPrimary)
            Text(label).font(.dsCaption).foregroundStyle(chefTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(chefTheme.cardBorder.opacity(0.6))
            .frame(width: DS.Stroke.hairline, height: 36)
    }

    private var groceryListLink: some View {
        NavigationLink {
            GroceryListView(plan: plan)
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(chefTheme.accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "cart.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(chefTheme.accent)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text("Grocery List")
                        .font(.dsBodyEmph)
                        .foregroundStyle(chefTheme.textPrimary)
                    Text("\(plan.groceryList.count) items for the week")
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
        .disabled(selectionMode)
    }

    // MARK: - Image generation entry / progress

    @ViewBuilder
    private var imagesCard: some View {
        if pipeline.isGeneratingImages {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ProgressView().tint(chefTheme.accent)
                    Text("Generating images · \(pipeline.imagesCompleted) of \(pipeline.imagesTotal)")
                        .font(.dsBodyEmph)
                        .foregroundStyle(chefTheme.textPrimary)
                    Spacer()
                    Button("Stop") {
                        pipeline.cancelImageGeneration()
                        autoImagesRequested = false
                    }
                    .font(.dsBodyEmph)
                    .foregroundStyle(chefTheme.accent)
                }
                ProgressView(value: Double(pipeline.imagesCompleted),
                             total: Double(max(1, pipeline.imagesTotal)))
                    .tint(chefTheme.accent)
                Text("You can browse the recipes or leave the app — images save as they finish.")
                    .font(.dsCaption)
                    .foregroundStyle(chefTheme.textTertiary)
            }
            .minimalCard(chefTheme)
        } else if selectionMode {
            HStack(spacing: 12) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(chefTheme.accent)
                Text("Tap the recipes you want images for")
                    .font(.dsBodyEmph)
                    .foregroundStyle(chefTheme.textPrimary)
                Spacer()
                Button(selectedCount == pendingImageCount ? "Clear" : "All") {
                    if selectedCount == pendingImageCount {
                        selectedMealIDs.removeAll()
                    } else {
                        selectedMealIDs = Set(selectableMeals.map(\.id))
                    }
                }
                .font(.dsBodyEmph)
                .foregroundStyle(chefTheme.accent)
            }
            .minimalCard(chefTheme)
        } else if pendingImageCount > 0 {
            Button {
                HapticManager.light()
                selectedMealIDs = []
                withAnimation { selectionMode = true }
            } label: {
                HStack(spacing: 14) {
                    Circle()
                        .fill(chefTheme.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 18))
                                .foregroundStyle(chefTheme.accent)
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Add images to your meals")
                            .font(.dsBodyEmph)
                            .foregroundStyle(chefTheme.textPrimary)
                        Text("Pick which recipes to illustrate · 1 credit each")
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

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                withAnimation { selectionMode = false }
                selectedMealIDs.removeAll()
            }
            .font(.dsBodyEmph)
            .foregroundStyle(chefTheme.textSecondary)

            Spacer()

            Button {
                Task { await generateSelected() }
            } label: {
                Text(selectedCount == 0 ? "Select recipes" : "Generate \(selectedCount) · \(selectedCount) credit\(selectedCount == 1 ? "" : "s")")
                    .font(.dsBodyEmph)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(selectedCount == 0 ? chefTheme.textQuaternary : chefTheme.accent))
            }
            .buttonStyle(PremiumCardButtonStyle())
            .disabled(selectedCount == 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Day / Meal cards

    private func daySection(day: Int, meals: [PlannedMeal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day \(day)")
                .font(.dsSection)
                .foregroundStyle(chefTheme.textPrimary)
            ForEach(meals) { meal in
                if selectionMode {
                    selectableMealCard(meal)
                } else {
                    NavigationLink {
                        MealDetailView(meal: meal)
                    } label: {
                        mealCardContent(meal)
                    }
                    .buttonStyle(PremiumCardButtonStyle())
                }
            }
        }
    }

    /// In selection mode, the whole card toggles selection (no navigation).
    private func selectableMealCard(_ meal: PlannedMeal) -> some View {
        let hasImage = meal.imageGenerated
        let isSelected = selectedMealIDs.contains(meal.id)
        return Button {
            guard !hasImage else { return }
            HapticManager.light()
            if isSelected { selectedMealIDs.remove(meal.id) } else { selectedMealIDs.insert(meal.id) }
        } label: {
            mealCardContent(meal, selectionBadge: hasImage ? .done : (isSelected ? .selected : .unselected))
        }
        .buttonStyle(PremiumCardButtonStyle())
        .disabled(hasImage)
        .opacity(hasImage ? 0.6 : 1)
    }

    private enum SelectionBadge { case none, selected, unselected, done }

    private func mealCardContent(_ meal: PlannedMeal, selectionBadge: SelectionBadge = .none) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                imageHeader(meal)
                if selectionBadge != .none {
                    badge(for: selectionBadge)
                        .padding(8)
                }
            }
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(meal.mealType.uppercased())
                        .font(.dsMicro)
                        .foregroundStyle(chefTheme.accent)
                    Text(meal.dishName)
                        .font(.dsBodyEmph)
                        .foregroundStyle(chefTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let cals = meal.nutrition?.calories {
                        Text("\(cals) cal" + (meal.cookTime.map { " · \($0)" } ?? ""))
                            .font(.dsCaption)
                            .foregroundStyle(chefTheme.textTertiary)
                    }
                }
                Spacer()
                if selectionBadge == .none {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(chefTheme.textQuaternary)
                }
            }
            .padding(.top, 12)
        }
        .minimalCard(chefTheme, padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 14))
    }

    @ViewBuilder
    private func badge(for state: SelectionBadge) -> some View {
        switch state {
        case .selected:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white, chefTheme.accent)
                .background(Circle().fill(.white).padding(3))
        case .unselected:
            Image(systemName: "circle")
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .shadow(radius: 2)
        case .done:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(chefTheme.accent)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func imageHeader(_ meal: PlannedMeal) -> some View {
        if let image = meal.generatedImage {
            Color.clear
                .frame(height: 150)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous))
        } else {
            let isThisGenerating = pipeline.currentImageMealID == meal.id
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.tile, style: .continuous)
                    .fill(chefTheme.accent.opacity(0.08))
                    .frame(height: selectionMode ? 110 : 90)
                if isThisGenerating {
                    VStack(spacing: 6) {
                        ProgressView().tint(chefTheme.accent)
                        Text("Creating image…").font(.dsMicro).foregroundStyle(chefTheme.accent)
                    }
                } else if pipeline.isGeneratingImages {
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 13, weight: .semibold))
                        Text("Queued").font(.dsCaption)
                    }
                    .foregroundStyle(chefTheme.textTertiary)
                } else if !selectionMode {
                    Button {
                        Task { await generateSingleImage(meal) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.badge.plus").font(.system(size: 16, weight: .semibold))
                            Text("Generate image · 1 credit").font(.dsCaption)
                        }
                        .foregroundStyle(chefTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(pipeline.currentImageMealID != nil)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundStyle(chefTheme.accent.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Actions

    private func generateSingleImage(_ meal: PlannedMeal) async {
        guard pipeline.currentImageMealID == nil, !pipeline.isGeneratingImages else { return }
        guard UsageTracker.shared.purchasedCredits >= 1 else { return }
        HapticManager.light()
        await pipeline.generateImage(for: meal, modelContext: modelContext)
    }

    private func exportPDF() {
        let data = PDFExporter.generateMealPlanPDF(for: plan)
        SharePresenter.presentPDF(data, fileName: plan.title)
    }

    private func deletePlan() async {
        await SyncManager.shared.deleteMealPlanRemotely(plan, modelContext: modelContext)
        dismiss()
    }

    private func sharePlanLink() async {
        guard AuthManager.shared.isAuthenticated else { shareError = "Sign in to share a link."; return }
        isPreparingShare = true
        defer { isPreparingShare = false }
        do {
            let url = try await SyncManager.shared.shareLinkForPlan(plan)
            SharePresenter.present([plan.title, url])
        } catch {
            shareError = "Couldn't create a link. Please try again."
        }
    }

    private func generateSelected() async {
        let chosen = selectableMeals.filter { selectedMealIDs.contains($0.id) }
        guard !chosen.isEmpty else { return }
        guard UsageTracker.shared.purchasedCredits >= 1 else { return }
        HapticManager.medium()
        queuedMealIDs = Set(chosen.map(\.id))
        autoImagesRequested = true
        withAnimation { selectionMode = false }
        selectedMealIDs.removeAll()
        await pipeline.generateImages(for: chosen, modelContext: modelContext)
    }
}
