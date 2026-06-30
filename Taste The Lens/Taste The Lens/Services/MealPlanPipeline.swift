import Foundation
import SwiftData
import UIKit
import Supabase
import os

private let logger = makeLogger(category: "MealPlanPipeline")

// MARK: - Edge Function Payloads

struct GenerateMealPlanRequest: Encodable {
    let chef: String
    let customChefConfig: CustomChefConfigPayload?
    let dietaryPreferences: [String]?
    let daysCount: Int
    let mealTypes: [String]
    let servings: Int
    let budgetLimit: Double?
    let caloriesPerMeal: Int?
    let skillLevel: String?
    /// Dish names already in the user's saved library — the model must not repeat these.
    let excludeDishes: [String]?
}

private struct MealPlanEnvelope: Decodable {
    let plan: MealPlanPayload
    let creditsCharged: Int
}

private struct MealPlanPayload: Decodable {
    let title: String
    let meals: [MealPayload]
    let grocery_list: [GroceryItem]
}

private struct MealPayload: Decodable {
    let day: Int
    let meal_type: String
    let dish_name: String
    let description: String
    let research_notes: String
    let sources: [String]
    let prep_time: String?
    let cook_time: String?
    let difficulty: String?
    let color_palette: [String]
    let image_generation_prompt: String
    let components: [RecipeComponent]
    let cooking_steps: [CookingStep]
    let nutrition: NutritionInfo?
}

// MARK: - Meal Plan Pipeline

/// Orchestrates weekly meal-plan generation: calls `generate-meal-plan` to build
/// the plan (researched, multi-credit), then optionally `generate-image` per meal
/// (lazy, 1 credit each). Mirrors ImageAnalysisPipeline's edge-function approach.
@Observable
@MainActor
final class MealPlanPipeline {
    enum State: Equatable {
        case idle
        case generating
        case success
        case failed(String)
    }

    var state: State = .idle
    var statusMessage: String = ""

    // Estimated progress for the recipe-bundle generation (the backend returns
    // all meals in one shot, so this is a smooth time-based estimate paired with
    // real phase labels — it eases toward ~92% and snaps to 100% on completion).
    var planProgress: Double = 0
    var planPhase: String = ""

    private static let planPhases = [
        "Researching recipes online…",
        "Checking nutrition & sources…",
        "Designing balanced meals…",
        "Writing recipes & cooking steps…",
        "Building your grocery list…",
        "Finishing up…",
    ]

    // Progressive image-queue state (observed by the UI for live updates).
    var isGeneratingImages = false
    var currentImageMealID: UUID?
    var imagesCompleted = 0
    var imagesTotal = 0
    private var cancelImageQueue = false

    /// Standard meal types in display order; used to assign a stable sortIndex.
    static let mealTypeOrder = ["Breakfast", "Lunch", "Dinner", "Snack"]

    /// Distinct dish names from the user's saved (non-deleted) meal plans, newest
    /// first, capped at `limit`. Used to tell the generator what NOT to repeat.
    static func recentLibraryDishNames(modelContext: ModelContext, limit: Int) -> [String] {
        let descriptor = FetchDescriptor<MealPlan>(
            predicate: #Predicate { !$0.isDeleted },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let plans = (try? modelContext.fetch(descriptor)) ?? []
        var names: [String] = []
        var seen = Set<String>()
        for plan in plans {
            for meal in plan.meals {
                let trimmed = meal.dishName.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = trimmed.lowercased()
                guard !trimmed.isEmpty, !seen.contains(key) else { continue }
                seen.insert(key)
                names.append(trimmed)
                if names.count >= limit { return names }
            }
        }
        return names
    }

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private func userAccessToken() async -> String? {
        guard AuthManager.shared.isAuthenticated,
              let session = try? await supabase.auth.session else { return nil }
        return session.accessToken
    }

    private func invokeEdgeFunction<Request: Encodable, Response: Decodable>(
        _ functionName: String,
        body: Request
    ) async throws -> Response {
        let baseURL = AppConfig.supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(baseURL)/functions/v1/\(functionName)") else {
            throw URLError(.badURL)
        }

        let encodedBody = try JSONEncoder().encode(body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300 // meal-plan generation + web research is slow
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(AppConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        if let userToken = await userAccessToken() {
            request.setValue(userToken, forHTTPHeaderField: "x-user-token")
        }
        request.httpBody = encodedBody

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            logger.error("Edge function \(functionName) returned \(httpResponse.statusCode): \(body)")
            throw EdgeFunctionError(statusCode: httpResponse.statusCode, body: body)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    // MARK: - Generate Plan

    /// Generates and persists a weekly meal plan. Returns the saved MealPlan on
    /// success, or nil on failure (state is set to `.failed`).
    @discardableResult
    func generatePlan(
        chef: ChefPersonality,
        daysCount: Int,
        mealTypes: [String],
        servings: Int,
        budgetLimit: Double?,
        caloriesPerMeal: Int?,
        modelContext: ModelContext
    ) async -> MealPlan? {
        guard NetworkMonitor.shared.isConnected else {
            state = .failed("No internet connection. Please check your network and try again.")
            return nil
        }

        state = .generating
        statusMessage = "Researching meals…"

        // Keep running briefly if the user backgrounds the app mid-generation.
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "MealPlanGenerate") {
            if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid }
        }
        defer { if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid } }

        // Estimated-progress ticker. Scales the estimate with the number of meals
        // (more meals → longer). Eases to ~92% and holds until the response lands.
        let totalMeals = daysCount * mealTypes.count
        planProgress = 0
        planPhase = Self.planPhases[0]
        let estimatedSeconds = Double(12 + totalMeals * 2)
        let tickInterval = 0.2
        let delta = 0.92 / max(1, estimatedSeconds / tickInterval)
        let ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(tickInterval * 1_000_000_000))
                guard let self else { return }
                if self.planProgress < 0.92 {
                    self.planProgress = min(0.92, self.planProgress + delta)
                }
                let idx = min(Self.planPhases.count - 1,
                              Int(self.planProgress / 0.92 * Double(Self.planPhases.count)))
                self.planPhase = Self.planPhases[idx]
            }
        }
        defer { ticker.cancel() }

        let dietaryPrefs = DietaryPreference.current()
        var customConfig: CustomChefConfigPayload?
        if chef == .custom, let config = CustomChefConfig.load() {
            customConfig = CustomChefConfigPayload(
                skillLevel: config.skillLevel.rawValue,
                cuisines: config.cuisines.map(\.rawValue),
                personality: config.personality.rawValue
            )
        }
        let userSkillLevel = UserDefaults.standard.string(forKey: "userSkillLevel")

        // De-dup against the user's existing library so new plans don't repeat
        // dishes they already have. Capped so the prompt stays bounded as the
        // library grows (deleting plans frees these names up again).
        let excludeDishes = Self.recentLibraryDishNames(modelContext: modelContext, limit: 50)

        let request = GenerateMealPlanRequest(
            chef: chef.rawValue,
            customChefConfig: customConfig,
            dietaryPreferences: dietaryPrefs.isEmpty ? nil : dietaryPrefs.map(\.rawValue),
            daysCount: daysCount,
            mealTypes: mealTypes,
            servings: servings,
            budgetLimit: budgetLimit,
            caloriesPerMeal: caloriesPerMeal,
            skillLevel: userSkillLevel,
            excludeDishes: excludeDishes.isEmpty ? nil : excludeDishes
        )

        do {
            let envelope: MealPlanEnvelope = try await invokeEdgeFunction("generate-meal-plan", body: request)

            let plan = MealPlan(
                title: envelope.plan.title,
                chefPersonality: chef.rawValue,
                daysCount: daysCount,
                mealsPerDay: mealTypes.count,
                groceryList: envelope.plan.grocery_list,
                userId: AuthManager.shared.currentUser?.id.uuidString
            )

            for m in envelope.plan.meals {
                let sortIndex = Self.mealTypeOrder.firstIndex(of: m.meal_type) ?? 99
                let meal = PlannedMeal(
                    day: m.day,
                    mealType: m.meal_type,
                    sortIndex: sortIndex,
                    dishName: m.dish_name,
                    mealDescription: m.description,
                    researchNotes: m.research_notes,
                    sources: m.sources,
                    prepTime: m.prep_time,
                    cookTime: m.cook_time,
                    difficulty: m.difficulty,
                    colorPalette: m.color_palette,
                    imageGenerationPrompt: m.image_generation_prompt,
                    components: m.components,
                    cookingSteps: m.cooking_steps,
                    nutrition: m.nutrition
                )
                meal.plan = plan
                plan.meals.append(meal)
            }

            modelContext.insert(plan)
            try? modelContext.save()

            planPhase = "Done"
            planProgress = 1.0

            // Refresh authoritative credit balance after the multi-credit charge.
            await UsageTracker.shared.syncCreditsFromServer()

            logger.info("Meal plan generated: \(plan.totalMealCount) meals, charged \(envelope.creditsCharged) credits")
            state = .success
            return plan
        } catch let error as EdgeFunctionError {
            logger.error("generatePlan failed: \(error.statusCode)")
            state = .failed(error.errorDescription ?? "Failed to generate meal plan.")
            return nil
        } catch {
            logger.error("generatePlan error: \(error.localizedDescription)")
            state = .failed("Failed to generate meal plan. Please try again.")
            return nil
        }
    }

    // MARK: - Generate Meal Image (opt-in, 1 credit)

    /// Generates a food image for a single meal and persists it. Returns true on
    /// success. Deducts 1 credit server-side via the generate-image flow.
    @discardableResult
    func generateImage(for meal: PlannedMeal, modelContext: ModelContext) async -> Bool {
        guard NetworkMonitor.shared.isConnected else { return false }
        guard !meal.imageGenerationPrompt.isEmpty else { return false }
        currentImageMealID = meal.id
        defer { if currentImageMealID == meal.id { currentImageMealID = nil } }

        do {
            let response: GenerateImageResponse = try await invokeEdgeFunction(
                "generate-image",
                body: GenerateImageRequest(
                    prompt: meal.imageGenerationPrompt,
                    provider: ImageGenerationModel.gptImage2.edgeFunctionKey,
                    chargeCredit: true
                )
            )
            guard let data = Data(base64Encoded: response.imageData) else { return false }
            meal.generatedImageData = data
            meal.imageGenerated = true
            try? modelContext.save()
            await UsageTracker.shared.syncCreditsFromServer()
            return true
        } catch {
            logger.error("generateImage failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Meals in a plan that still need an image, in day/meal order.
    func mealsNeedingImages(in plan: MealPlan) -> [PlannedMeal] {
        plan.meals
            .filter { !$0.imageGenerated && !$0.imageGenerationPrompt.isEmpty }
            .sorted { ($0.day, $0.sortIndex) < ($1.day, $1.sortIndex) }
    }

    /// Generates images for every meal in a plan that still needs one.
    func generateAllImages(for plan: MealPlan, modelContext: ModelContext) async {
        await generateImages(for: mealsNeedingImages(in: plan), modelContext: modelContext)
    }

    /// Generates images for the given meals (e.g. a user-selected subset), ONE
    /// AT A TIME, persisting each as it completes so the UI reveals them
    /// progressively. Wrapped in a background-task assertion so it keeps running
    /// for a while if the user backgrounds the app; it's resumable simply by
    /// calling again (meals that already have an image are skipped).
    func generateImages(for meals: [PlannedMeal], modelContext: ModelContext) async {
        guard !isGeneratingImages else { return }
        let pending = meals
            .filter { !$0.imageGenerated && !$0.imageGenerationPrompt.isEmpty }
            .sorted { ($0.day, $0.sortIndex) < ($1.day, $1.sortIndex) }
        guard !pending.isEmpty else { return }

        cancelImageQueue = false
        isGeneratingImages = true
        imagesTotal = pending.count
        imagesCompleted = 0

        // Ask iOS for extra execution time so backgrounding doesn't immediately
        // kill an in-flight generation. On expiration, stop the queue cleanly —
        // already-finished images are saved, and the rest resume on foreground.
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "MealPlanImages") { [weak self] in
            self?.cancelImageQueue = true
            if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid }
        }
        defer {
            isGeneratingImages = false
            currentImageMealID = nil
            if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid }
        }

        for meal in pending {
            if cancelImageQueue { break }
            guard NetworkMonitor.shared.isConnected else { break }
            // Stop early if the user is out of credits.
            guard UsageTracker.shared.purchasedCredits >= 1 else { break }

            let ok = await generateImage(for: meal, modelContext: modelContext)
            if ok { imagesCompleted += 1 }
            // If a generation fails (not a credit issue), keep going to the next.
        }
    }

    /// Signals the running image queue to stop after the current image.
    func cancelImageGeneration() {
        cancelImageQueue = true
    }
}
