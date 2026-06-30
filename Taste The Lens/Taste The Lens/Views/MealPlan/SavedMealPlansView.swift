import SwiftUI
import SwiftData

/// Saved hub for the meal-plan world: browse Plans, Favorite Meals, and Shared
/// items. Presented as a sheet from the dashboard.
struct SavedMealPlansView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedChef") private var selectedChef = "default"

    @Query(filter: #Predicate<MealPlan> { !$0.isDeleted }, sort: \MealPlan.createdAt, order: .reverse)
    private var plans: [MealPlan]

    @Query(filter: #Predicate<PlannedMeal> { $0.isFavorite }, sort: \PlannedMeal.day)
    private var favoriteMeals: [PlannedMeal]

    @State private var segment: Segment = .plans
    @State private var showSetup = false

    private enum Segment: String, CaseIterable {
        case plans = "Plans"
        case favorites = "Favorites"
        case shared = "Shared"
    }

    private var chefTheme: ChefTheme {
        ChefPersonality(rawValue: selectedChef)?.theme ?? ChefPersonality.defaultChef.theme
    }

    private var favoritePlans: [MealPlan] { plans.filter(\.isFavorite) }
    private var sharedPlans: [MealPlan] { plans.filter { $0.remoteId != nil } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("", selection: $segment) {
                        ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 4)

                    switch segment {
                    case .plans: plansSection
                    case .favorites: favoritesSection
                    case .shared: sharedSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .background(chefTheme.dashboardBg.ignoresSafeArea())
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(chefTheme.accent)
                }
            }
            .sheet(isPresented: $showSetup) { MealPlanSetupView() }
        }
        .tint(chefTheme.accent)
    }

    // MARK: - Plans

    @ViewBuilder
    private var plansSection: some View {
        newPlanButton
        if plans.isEmpty {
            emptyState(icon: "calendar.badge.plus", title: "No meal plans yet", subtitle: "Create your first researched weekly plan.")
        } else {
            ForEach(plans) { plan in
                NavigationLink { MealPlanView(plan: plan) } label: { planRow(plan) }
                    .buttonStyle(PremiumCardButtonStyle())
                    .contextMenu { deleteButton(for: plan) }
            }
        }
    }

    // MARK: - Favorites

    @ViewBuilder
    private var favoritesSection: some View {
        if favoritePlans.isEmpty && favoriteMeals.isEmpty {
            emptyState(icon: "heart", title: "No favorites yet", subtitle: "Tap the heart on a meal or plan to save it here.")
        } else {
            if !favoritePlans.isEmpty {
                sectionLabel("Plans")
                ForEach(favoritePlans) { plan in
                    NavigationLink { MealPlanView(plan: plan) } label: { planRow(plan) }
                        .buttonStyle(PremiumCardButtonStyle())
                        .contextMenu { deleteButton(for: plan) }
                }
            }
            if !favoriteMeals.isEmpty {
                sectionLabel("Meals")
                ForEach(favoriteMeals) { meal in
                    NavigationLink { MealDetailView(meal: meal) } label: { mealRow(meal) }
                        .buttonStyle(PremiumCardButtonStyle())
                }
            }
        }
    }

    // MARK: - Shared

    @ViewBuilder
    private var sharedSection: some View {
        if sharedPlans.isEmpty {
            emptyState(icon: "square.and.arrow.up", title: "Nothing shared yet", subtitle: "Use \u{201C}Share plan link\u{201D} on a plan to make it openable by other app users.")
        } else {
            ForEach(sharedPlans) { plan in
                NavigationLink { MealPlanView(plan: plan) } label: { planRow(plan, showSharedBadge: true) }
                    .buttonStyle(PremiumCardButtonStyle())
                    .contextMenu { deleteButton(for: plan) }
            }
        }
    }

    @ViewBuilder
    private func deleteButton(for plan: MealPlan) -> some View {
        Button(role: .destructive) {
            Task { await SyncManager.shared.deleteMealPlanRemotely(plan, modelContext: modelContext) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Rows

    private var newPlanButton: some View {
        Button {
            HapticManager.light()
            showSetup = true
        } label: {
            HStack(spacing: 14) {
                Circle().fill(chefTheme.accent.opacity(0.12)).frame(width: 44, height: 44)
                    .overlay(Image(systemName: "plus").font(.system(size: 18, weight: .medium)).foregroundStyle(chefTheme.accent))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Create a Weekly Meal Plan").font(.dsBodyEmph).foregroundStyle(chefTheme.textPrimary)
                    Text("Researched meals, grocery list & cooking steps").font(.dsCaption).foregroundStyle(chefTheme.textTertiary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(chefTheme.textQuaternary)
            }
            .minimalCard(chefTheme)
        }
        .buttonStyle(PremiumCardButtonStyle())
    }

    private func planRow(_ plan: MealPlan, showSharedBadge: Bool = false) -> some View {
        HStack(spacing: 14) {
            Circle().fill(chefTheme.accent.opacity(0.12)).frame(width: 48, height: 48)
                .overlay(Image(systemName: "calendar").font(.system(size: 20)).foregroundStyle(chefTheme.accent))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(plan.title).font(.dsBodyEmph).foregroundStyle(chefTheme.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                    if plan.isFavorite { Image(systemName: "heart.fill").font(.system(size: 11)).foregroundStyle(.pink) }
                }
                Text("\(plan.daysCount) days · \(plan.totalMealCount) meals · \(plan.createdAt.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.dsCaption).foregroundStyle(chefTheme.textTertiary)
            }
            Spacer()
            if showSharedBadge {
                Image(systemName: "link").font(.system(size: 12, weight: .semibold)).foregroundStyle(chefTheme.accent)
            } else {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(chefTheme.textQuaternary)
            }
        }
        .minimalCard(chefTheme)
    }

    private func mealRow(_ meal: PlannedMeal) -> some View {
        HStack(spacing: 12) {
            Group {
                if let image = meal.generatedImage {
                    Color.clear.overlay { Image(uiImage: image).resizable().aspectRatio(contentMode: .fill) }
                } else {
                    chefTheme.accent.opacity(0.10).overlay(Image(systemName: "fork.knife").foregroundStyle(chefTheme.accent.opacity(0.5)))
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(meal.mealType.uppercased()).font(.dsMicro).foregroundStyle(chefTheme.accent)
                Text(meal.dishName).font(.dsBodyEmph).foregroundStyle(chefTheme.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(chefTheme.textQuaternary)
        }
        .minimalCard(chefTheme, radius: DS.Radius.tile, padding: EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 14))
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text).font(.dsSection).foregroundStyle(chefTheme.textPrimary)
            Spacer()
        }
        .padding(.top, 4)
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Circle().fill(chefTheme.accent.opacity(0.10)).frame(width: 64, height: 64)
                .overlay(Image(systemName: icon).font(.system(size: 26)).foregroundStyle(chefTheme.accent))
            Text(title).font(.dsBodyEmph).foregroundStyle(chefTheme.textPrimary)
            Text(subtitle).font(.dsCaption).foregroundStyle(chefTheme.textTertiary)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
