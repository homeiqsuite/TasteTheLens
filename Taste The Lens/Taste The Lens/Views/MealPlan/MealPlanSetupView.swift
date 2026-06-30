import SwiftUI
import SwiftData

/// Configure a weekly meal plan (days, meals/day, servings, optional budget),
/// preview the credit cost, then generate. On success, pushes MealPlanView.
struct MealPlanSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("selectedChef") private var selectedChef = "default"

    @State private var daysCount = 7
    @State private var selectedMealTypes: Set<String> = ["Breakfast", "Lunch", "Dinner"]
    @State private var servings = 2
    @State private var useBudget = false
    @State private var budget: Double = 75
    @State private var useCalorieTarget = false
    @State private var caloriesPerMeal = 500

    @State private var pipeline = MealPlanPipeline()
    @State private var generatedPlan: MealPlan?
    @State private var showPaywall = false

    private let allMealTypes = MealPlanPipeline.mealTypeOrder

    private var chef: ChefPersonality { ChefPersonality(rawValue: selectedChef) ?? .defaultChef }
    private var chefTheme: ChefTheme { chef.theme }

    private var orderedMealTypes: [String] {
        allMealTypes.filter { selectedMealTypes.contains($0) }
    }
    private var totalMeals: Int { daysCount * max(1, selectedMealTypes.count) }

    private var isGenerating: Bool { pipeline.state == .generating }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    daysCard
                    mealTypesCard
                    servingsCard
                    calorieCard
                    budgetCard
                    costSummaryCard
                    generateButton
                    if case .failed(let message) = pipeline.state {
                        Text(message)
                            .font(.dsCaption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .background(chefTheme.dashboardBg.ignoresSafeArea())
            .navigationTitle("Weekly Meal Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(chefTheme.accent)
                }
            }
            .navigationDestination(item: $generatedPlan) { plan in
                MealPlanView(plan: plan)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: .featureGated(.chefPersonalities))
            }
            .overlay {
                if isGenerating { generatingOverlay }
            }
        }
        .tint(chefTheme.accent)
    }

    // MARK: - Cards

    private var headerCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(chefTheme.accent.opacity(0.12))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: chef.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(chefTheme.accent)
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(chef.displayName)
                    .font(.dsBodyEmph)
                    .foregroundStyle(chefTheme.textPrimary)
                Text("Researched meals, a grocery list, and cooking steps for your week.")
                    .font(.dsCaption)
                    .foregroundStyle(chefTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .minimalCard(chefTheme)
    }

    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("How many days?")
            Stepper(value: $daysCount, in: 1...7) {
                Text("\(daysCount) day\(daysCount == 1 ? "" : "s")")
                    .font(.dsBodyEmph)
                    .foregroundStyle(chefTheme.textPrimary)
            }
            .tint(chefTheme.accent)
        }
        .minimalCard(chefTheme)
    }

    private var mealTypesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Meals per day")
            FlowChips(items: allMealTypes, isSelected: { selectedMealTypes.contains($0) }, theme: chefTheme) { type in
                if selectedMealTypes.contains(type) {
                    if selectedMealTypes.count > 1 { selectedMealTypes.remove(type) }
                } else {
                    selectedMealTypes.insert(type)
                }
            }
        }
        .minimalCard(chefTheme)
    }

    private var servingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("Servings per meal")
            Stepper(value: $servings, in: 1...12) {
                Text("\(servings) serving\(servings == 1 ? "" : "s")")
                    .font(.dsBodyEmph)
                    .foregroundStyle(chefTheme.textPrimary)
            }
            .tint(chefTheme.accent)
        }
        .minimalCard(chefTheme)
    }

    private var calorieCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $useCalorieTarget) {
                cardTitle("Calorie target per meal")
            }
            .tint(chefTheme.accent)
            if useCalorieTarget {
                HStack {
                    Text("\(caloriesPerMeal) cal")
                        .font(.dsMetric)
                        .foregroundStyle(chefTheme.accent)
                    Stepper(value: $caloriesPerMeal, in: 150...1200, step: 50) {
                        EmptyView()
                    }
                    .labelsHidden()
                }
                Text("Each meal will aim for about \(caloriesPerMeal) calories per serving.")
                    .font(.dsCaption)
                    .foregroundStyle(chefTheme.textTertiary)
            }
        }
        .minimalCard(chefTheme)
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $useBudget) {
                cardTitle("Weekly grocery budget")
            }
            .tint(chefTheme.accent)
            if useBudget {
                HStack {
                    Text("$\(Int(budget))")
                        .font(.dsMetric)
                        .foregroundStyle(chefTheme.accent)
                    Slider(value: $budget, in: 25...300, step: 5)
                        .tint(chefTheme.accent)
                }
            }
        }
        .minimalCard(chefTheme)
    }

    private var costSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardTitle("Credit cost")
            costRow(label: "\(totalMeals) meal recipes", value: "\(totalMeals) credits", emphasized: true)
            Divider().background(chefTheme.cardBorder)
            costRow(label: "Meal images (optional, add later)", value: "+1 credit each", emphasized: false)
            Text("You have \(UsageTracker.shared.purchasedCredits) credits.")
                .font(.dsCaption)
                .foregroundStyle(chefTheme.textTertiary)
                .padding(.top, 2)
        }
        .minimalCard(chefTheme)
    }

    private func costRow(label: String, value: String, emphasized: Bool) -> some View {
        HStack {
            Text(label)
                .font(.dsBody)
                .foregroundStyle(chefTheme.textSecondary)
            Spacer()
            Text(value)
                .font(emphasized ? .dsBodyEmph : .dsBody)
                .foregroundStyle(emphasized ? chefTheme.accent : chefTheme.textTertiary)
        }
    }

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                Text("Generate Plan — \(totalMeals) credits")
                    .font(.dsBodyEmph)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Capsule().fill(chefTheme.accent))
        }
        .buttonStyle(PremiumCardButtonStyle())
        .disabled(isGenerating)
        .padding(.top, 4)
    }

    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(chefTheme.accent.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: chef.icon)
                        .font(.system(size: 26))
                        .foregroundStyle(chefTheme.accent)
                }

                VStack(spacing: 6) {
                    Text("Building your meal plan")
                        .font(.dsSection)
                        .foregroundStyle(chefTheme.textPrimary)
                    Text(pipeline.planPhase.isEmpty ? "Starting…" : pipeline.planPhase)
                        .font(.dsBody)
                        .foregroundStyle(chefTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(.easeInOut, value: pipeline.planPhase)
                }

                VStack(spacing: 8) {
                    ProgressView(value: pipeline.planProgress)
                        .tint(chefTheme.accent)
                        .animation(.linear(duration: 0.2), value: pipeline.planProgress)
                    HStack {
                        Text("\(Int(pipeline.planProgress * 100))%")
                            .font(.dsCaption)
                            .foregroundStyle(chefTheme.accent)
                            .contentTransition(.numericText())
                        Spacer()
                        Text("Planning \(totalMeals) meals")
                            .font(.dsCaption)
                            .foregroundStyle(chefTheme.textTertiary)
                    }
                }

                Text("Researching real sources for each meal — this can take up to a minute. You can keep the app open while it works.")
                    .font(.dsMicro)
                    .foregroundStyle(chefTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                    .fill(chefTheme.cardBg)
                    .shadow(color: chefTheme.cardShadow, radius: 20, y: 8)
            )
            .padding(.horizontal, 32)
        }
    }

    private func cardTitle(_ text: String) -> some View {
        Text(text)
            .font(.dsSection)
            .foregroundStyle(chefTheme.textPrimary)
    }

    // MARK: - Actions

    private func generate() async {
        // Premium gate (mirrors chef gating) + credit check.
        guard EntitlementManager.shared.hasEverPurchased else {
            showPaywall = true
            return
        }
        guard UsageTracker.shared.purchasedCredits >= totalMeals else {
            showPaywall = true
            return
        }
        HapticManager.medium()
        let plan = await pipeline.generatePlan(
            chef: chef,
            daysCount: daysCount,
            mealTypes: orderedMealTypes,
            servings: servings,
            budgetLimit: useBudget ? budget : nil,
            caloriesPerMeal: useCalorieTarget ? caloriesPerMeal : nil,
            modelContext: modelContext
        )
        if let plan {
            generatedPlan = plan
        }
    }
}

/// Simple wrapping chip selector.
private struct FlowChips: View {
    let items: [String]
    let isSelected: (String) -> Bool
    let theme: ChefTheme
    let onTap: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let selected = isSelected(item)
                Button {
                    HapticManager.light()
                    onTap(item)
                } label: {
                    Text(item)
                        .font(.dsCaption)
                        .foregroundStyle(selected ? .white : theme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(selected ? theme.accent : theme.accent.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}
