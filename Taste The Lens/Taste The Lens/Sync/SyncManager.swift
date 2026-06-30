import Foundation
import UIKit
import SwiftData
import Supabase
import os

private let logger = makeLogger(category: "Sync")

@Observable
final class SyncManager {
    static let shared = SyncManager()

    var isSyncing = false

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    private init() {}

    // MARK: - Sync Single Recipe

    /// Upload a local recipe to Supabase (images → storage, metadata → recipes table).
    @MainActor
    func syncRecipe(_ recipe: Recipe) async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString.lowercased() else {
            logger.warning("Cannot sync — not authenticated")
            return
        }

        recipe.syncStatus = "syncing"
        recipe.userId = userId

        do {
            // Upload inspiration image (compressed for cloud storage)
            let inspirationPath = "\(userId)/\(recipe.id.uuidString)/inspiration.jpg"
            let compressedInspiration = UIImage.compressForCloudUpload(recipe.inspirationImageData)
            try await supabase.storage
                .from("inspiration-images")
                .upload(inspirationPath, data: compressedInspiration, options: .init(upsert: true))

            // Upload dish image if available (compressed for cloud storage)
            var dishImagePath: String? = nil
            if let dishData = recipe.generatedDishImageData {
                dishImagePath = "\(userId)/\(recipe.id.uuidString)/dish.jpg"
                let compressedDish = UIImage.compressForCloudUpload(dishData)
                try await supabase.storage
                    .from("dish-images")
                    .upload(dishImagePath!, data: compressedDish, options: .init(upsert: true))
            }

            // Upsert recipe row
            let dto = SupabaseRecipeDTO.from(
                recipe: recipe,
                userId: userId,
                inspirationPath: inspirationPath,
                dishImagePath: dishImagePath
            )

            if let remoteId = recipe.remoteId {
                // Update existing
                try await supabase.from("recipes")
                    .update(dto)
                    .eq("id", value: remoteId)
                    .execute()
            } else {
                // Insert new
                let response: [SupabaseRecipeDTO] = try await supabase.from("recipes")
                    .insert(dto)
                    .select()
                    .execute()
                    .value

                if let newId = response.first?.id {
                    recipe.remoteId = newId
                }
            }

            recipe.syncStatus = "synced"
            logger.info("Recipe synced: \(recipe.dishName)")
        } catch {
            recipe.syncStatus = "failed"
            logger.error("Sync failed for \(recipe.dishName): \(error)")
        }
    }

    // MARK: - Pull Remote Recipes

    /// Download recipes from Supabase that don't exist locally.
    @MainActor
    func pullRemoteRecipes(modelContext: ModelContext) async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }

        do {
            let remoteDTOs: [SupabaseRecipeDTO] = try await supabase.from("recipes")
                .select()
                .eq("user_id", value: userId)
                .eq("is_deleted", value: false)
                .execute()
                .value

            // Get local remote IDs
            let descriptor = FetchDescriptor<Recipe>()
            let localRecipes = (try? modelContext.fetch(descriptor)) ?? []
            let localRemoteIds = Set(localRecipes.compactMap(\.remoteId))

            var newCount = 0
            for dto in remoteDTOs {
                guard let remoteId = dto.id, !localRemoteIds.contains(remoteId) else { continue }

                // Download images
                let inspirationData: Data
                if let path = dto.inspirationImagePath {
                    inspirationData = try await supabase.storage
                        .from("inspiration-images")
                        .download(path: path)
                } else {
                    continue // Skip recipes without inspiration image
                }

                var dishImageData: Data? = nil
                if let path = dto.dishImagePath {
                    dishImageData = try await supabase.storage
                        .from("dish-images")
                        .download(path: path)
                }

                let recipe = dto.toRecipe(inspirationData: inspirationData, dishImageData: dishImageData)
                modelContext.insert(recipe)
                newCount += 1
            }

            if newCount > 0 {
                try modelContext.save()
                logger.info("Pulled \(newCount) new recipes from cloud")
            }
        } catch {
            logger.error("Pull remote recipes failed: \(error)")
        }
    }

    // MARK: - Sync All

    /// Push pending local recipes + pull remote ones.
    @MainActor
    func syncAll(modelContext: ModelContext) async {
        guard AuthManager.shared.isAuthenticated else { return }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        logger.info("Starting full sync")

        // Push unsynced local recipes
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.syncStatus == "local" || recipe.syncStatus == "failed"
            }
        )

        let unsyncedRecipes = (try? modelContext.fetch(descriptor)) ?? []
        for recipe in unsyncedRecipes {
            await syncRecipe(recipe)
        }

        // Pull remote recipes
        await pullRemoteRecipes(modelContext: modelContext)

        logger.info("Full sync complete")
    }

    // MARK: - Fetch Single Recipe by Remote ID

    /// Fetch a recipe from Supabase by its remote ID (for deep-link resolution).
    /// Returns a hydrated Recipe (with images) that is NOT inserted into any model context.
    func fetchRecipe(shareToken: String) async throws -> Recipe {
        logger.info("DeepLink: fetching shared recipe")

        let rows: [SupabaseRecipeDTO]
        do {
            rows = try await supabase
                .rpc("get_shared_recipe", params: ["p_token": shareToken])
                .execute()
                .value
        } catch {
            logger.error("DeepLink: get_shared_recipe failed — \(error)")
            throw error
        }
        guard let dto = rows.first else {
            logger.error("DeepLink: no shared recipe found for token")
            throw URLError(.resourceUnavailable)
        }
        logger.info("DeepLink: recipe row found — \"\(dto.dishName)\"")

        guard let inspirationPath = dto.inspirationImagePath else {
            logger.error("DeepLink: no inspiration_image_path on shared recipe")
            throw URLError(.resourceUnavailable)
        }

        logger.info("DeepLink: downloading inspiration image at \(inspirationPath)")
        let inspirationData: Data
        do {
            inspirationData = try await supabase.storage
                .from("inspiration-images")
                .download(path: inspirationPath)
            logger.info("DeepLink: inspiration image downloaded (\(inspirationData.count) bytes)")
        } catch {
            logger.error("DeepLink: inspiration image download failed — \(error)")
            throw error
        }

        var dishImageData: Data? = nil
        if let dishPath = dto.dishImagePath {
            logger.info("DeepLink: downloading dish image at \(dishPath)")
            do {
                dishImageData = try await supabase.storage
                    .from("dish-images")
                    .download(path: dishPath)
                logger.info("DeepLink: dish image downloaded (\(dishImageData?.count ?? 0) bytes)")
            } catch {
                logger.warning("DeepLink: dish image download failed (non-fatal) — \(error)")
            }
        }

        logger.info("DeepLink: recipe hydrated successfully — \"\(dto.dishName)\"")
        return dto.toRecipe(inspirationData: inspirationData, dishImageData: dishImageData)
    }

    // MARK: - Meal Plan Sharing/Sync

    /// Upload a local meal plan (and its meals + images) to Supabase so it can be
    /// shared via deep link. Sets `remoteId` on the plan and each meal.
    @MainActor
    func syncMealPlan(_ plan: MealPlan) async throws {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString.lowercased() else {
            throw URLError(.userAuthenticationRequired)
        }

        plan.syncStatus = "syncing"
        plan.userId = userId

        do {
            // 1. Upsert the plan row.
            let planDTO = SupabaseMealPlanDTO.from(plan: plan, userId: userId)
            let planRemoteId: String
            if let existing = plan.remoteId {
                try await supabase.from("meal_plans").update(planDTO).eq("id", value: existing).execute()
                planRemoteId = existing
            } else {
                let inserted: [SupabaseMealPlanDTO] = try await supabase.from("meal_plans")
                    .insert(planDTO).select().execute().value
                guard let newId = inserted.first?.id else { throw URLError(.cannotParseResponse) }
                plan.remoteId = newId
                planRemoteId = newId
            }

            // 2. Upsert each meal (uploading its image if present).
            for meal in plan.meals {
                var imagePath: String? = nil
                if let imageData = meal.generatedImageData {
                    let path = "\(userId)/\(planRemoteId)/\(meal.id.uuidString).jpg"
                    let compressed = UIImage.compressForCloudUpload(imageData)
                    try await supabase.storage.from("meal-images")
                        .upload(path, data: compressed, options: .init(upsert: true))
                    imagePath = path
                }

                let mealDTO = SupabaseMealDTO.from(meal: meal, mealPlanId: planRemoteId, imagePath: imagePath)
                if let existing = meal.remoteId {
                    try await supabase.from("meal_plan_meals").update(mealDTO).eq("id", value: existing).execute()
                } else {
                    let inserted: [SupabaseMealDTO] = try await supabase.from("meal_plan_meals")
                        .insert(mealDTO).select().execute().value
                    meal.remoteId = inserted.first?.id
                }
            }

            plan.syncStatus = "synced"
            logger.info("Meal plan synced: \(plan.title)")
        } catch {
            plan.syncStatus = "failed"
            logger.error("Meal plan sync failed for \(plan.title): \(error)")
            throw error
        }
    }

    /// Fetch a shared meal plan by remote id (deep-link resolution). Returns a
    /// transient MealPlan (with meals + images) not inserted into any context.
    func fetchMealPlan(shareToken: String) async throws -> MealPlan {
        logger.info("DeepLink: fetching shared meal plan")

        let planRows: [SupabaseMealPlanDTO] = try await supabase
            .rpc("get_shared_meal_plan", params: ["p_token": shareToken])
            .execute()
            .value
        guard let planDTO = planRows.first else {
            throw URLError(.resourceUnavailable)
        }

        let mealDTOs: [SupabaseMealDTO] = try await supabase
            .rpc("get_shared_meal_plan_meals", params: ["p_token": shareToken])
            .execute()
            .value

        var meals: [PlannedMeal] = []
        for dto in mealDTOs {
            var imageData: Data? = nil
            if let path = dto.imagePath {
                imageData = try? await supabase.storage.from("meal-images").download(path: path)
            }
            meals.append(dto.toPlannedMeal(imageData: imageData))
        }

        logger.info("DeepLink: meal plan hydrated — \"\(planDTO.title)\" (\(meals.count) meals)")
        return planDTO.toMealPlan(meals: meals)
    }

    /// Fetch a single shared meal by remote id (deep-link resolution).
    func fetchMeal(planToken: String, mealId: String) async throws -> PlannedMeal {
        logger.info("DeepLink: fetching shared meal")

        let mealDTOs: [SupabaseMealDTO] = try await supabase
            .rpc("get_shared_meal_plan_meals", params: ["p_token": planToken])
            .execute()
            .value
        guard let dto = mealDTOs.first(where: { $0.id == mealId }) else {
            throw URLError(.resourceUnavailable)
        }

        var imageData: Data? = nil
        if let path = dto.imagePath {
            imageData = try? await supabase.storage.from("meal-images").download(path: path)
        }
        return dto.toPlannedMeal(imageData: imageData)
    }

    // MARK: - Share Link Minting (token-scoped)

    /// Ensure the recipe is synced, mint (or fetch) its share token, return a share URL.
    @MainActor
    func shareLinkForRecipe(_ recipe: Recipe) async throws -> URL {
        if recipe.remoteId == nil {
            await syncRecipe(recipe)
        }
        guard let remoteId = recipe.remoteId else { throw URLError(.cannotCreateFile) }
        let token = try await mintShareToken(rpc: "share_recipe", id: remoteId)
        guard let url = DeepLinkHandler.recipeURL(token: token) else { throw URLError(.badURL) }
        return url
    }

    /// Ensure the plan is synced, mint (or fetch) its share token, return a share URL.
    @MainActor
    func shareLinkForPlan(_ plan: MealPlan) async throws -> URL {
        if plan.remoteId == nil {
            try await syncMealPlan(plan)
        }
        guard let remoteId = plan.remoteId else { throw URLError(.cannotCreateFile) }
        let token = try await mintShareToken(rpc: "share_meal_plan", id: remoteId)
        guard let url = DeepLinkHandler.mealPlanURL(token: token) else { throw URLError(.badURL) }
        return url
    }

    /// Ensure the meal's parent plan is synced, mint the plan's share token, return a
    /// share URL that points at the single meal.
    @MainActor
    func shareLinkForMeal(_ meal: PlannedMeal) async throws -> URL {
        guard let plan = meal.plan else { throw URLError(.cannotCreateFile) }
        if plan.remoteId == nil {
            try await syncMealPlan(plan)
        }
        guard let planRemoteId = plan.remoteId, let mealId = meal.remoteId else {
            throw URLError(.cannotCreateFile)
        }
        let token = try await mintShareToken(rpc: "share_meal_plan", id: planRemoteId)
        guard let url = DeepLinkHandler.mealURL(planToken: token, mealId: mealId) else {
            throw URLError(.badURL)
        }
        return url
    }

    /// Calls an owner-only share RPC (`share_recipe` / `share_meal_plan`) that
    /// returns the item's share token.
    private func mintShareToken(rpc: String, id: String) async throws -> String {
        let rows: [ShareTokenRow] = try await supabase
            .rpc(rpc, params: ["p_id": id])
            .execute()
            .value
        guard let token = rows.first?.token else { throw URLError(.cannotCreateFile) }
        return token.uuidString.lowercased()
    }

    // MARK: - Delete Recipe (Soft-Delete on Server)

    /// Soft-delete a recipe on Supabase (sets `is_deleted = true`), then hard-delete locally.
    @MainActor
    func deleteRecipeRemotely(_ recipe: Recipe, modelContext: ModelContext) async {
        if let remoteId = recipe.remoteId {
            do {
                try await supabase.from("recipes")
                    .update(["is_deleted": true])
                    .eq("id", value: remoteId)
                    .execute()
                logger.info("Marked recipe as deleted on server: \(recipe.dishName)")
            } catch {
                logger.error("Failed to delete recipe remotely: \(error)")
            }
        }
        modelContext.delete(recipe)
        try? modelContext.save()
    }

    /// Soft-delete a meal plan on Supabase (if synced), then hard-delete locally
    /// (cascades to its meals). After this, any shared links stop resolving.
    @MainActor
    func deleteMealPlanRemotely(_ plan: MealPlan, modelContext: ModelContext) async {
        if let remoteId = plan.remoteId {
            do {
                try await supabase.from("meal_plans")
                    .update(["is_deleted": true])
                    .eq("id", value: remoteId)
                    .execute()
                logger.info("Marked meal plan as deleted on server: \(plan.title)")
            } catch {
                logger.error("Failed to delete meal plan remotely: \(error)")
            }
        }
        modelContext.delete(plan)
        try? modelContext.save()
    }

    // MARK: - Claim Local Recipes

    /// On first sign-in, assign unowned local recipes to the current user.
    @MainActor
    func claimLocalRecipes(modelContext: ModelContext) async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }

        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate<Recipe> { recipe in
                recipe.userId == nil
            }
        )

        let unownedRecipes = (try? modelContext.fetch(descriptor)) ?? []
        for recipe in unownedRecipes {
            recipe.userId = userId
            recipe.syncStatus = "local" // Mark for sync
        }

        if !unownedRecipes.isEmpty {
            try? modelContext.save()
            logger.info("Claimed \(unownedRecipes.count) local recipes for user \(userId)")
        }
    }

    // MARK: - Dietary Preferences Sync

    func syncDietaryPreferences() async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            logger.warning("Cannot sync dietary preferences — not authenticated")
            return
        }

        let prefs = DietaryPreference.current().map(\.rawValue)
        do {
            try await supabase
                .from("users")
                .update(["dietary_preferences": prefs])
                .eq("id", value: userId)
                .execute()
            logger.info("Dietary preferences synced to server")
        } catch {
            logger.error("Failed to sync dietary preferences: \(error)")
        }
    }

    func pullDietaryPreferences() async {
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }

        do {
            let response: [DietaryPrefsRow] = try await supabase
                .from("users")
                .select("dietary_preferences")
                .eq("id", value: userId)
                .execute()
                .value

            if let row = response.first, !row.dietaryPreferences.isEmpty {
                let prefs = row.dietaryPreferences.compactMap { DietaryPreference(rawValue: $0) }
                if !prefs.isEmpty {
                    DietaryPreference.save(prefs)
                    logger.info("Pulled \(prefs.count) dietary preferences from server")
                }
            }
        } catch {
            logger.error("Failed to pull dietary preferences: \(error)")
        }
    }
}

private struct DietaryPrefsRow: Codable {
    let dietaryPreferences: [String]

    enum CodingKeys: String, CodingKey {
        case dietaryPreferences = "dietary_preferences"
    }
}

/// Decodes the single-column result of the `share_recipe` / `share_meal_plan` RPCs.
private struct ShareTokenRow: Decodable {
    let token: UUID
}
