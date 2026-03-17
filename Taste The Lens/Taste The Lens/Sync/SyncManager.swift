import Foundation
import SwiftData
import Supabase
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "Sync")

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
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else {
            logger.warning("Cannot sync — not authenticated")
            return
        }

        recipe.syncStatus = "syncing"
        recipe.userId = userId

        do {
            // Upload inspiration image
            let inspirationPath = "\(userId)/\(recipe.id.uuidString)/inspiration.jpg"
            try await supabase.storage
                .from("inspiration-images")
                .upload(inspirationPath, data: recipe.inspirationImageData, options: .init(upsert: true))

            // Upload dish image if available
            var dishImagePath: String? = nil
            if let dishData = recipe.generatedDishImageData {
                dishImagePath = "\(userId)/\(recipe.id.uuidString)/dish.jpg"
                try await supabase.storage
                    .from("dish-images")
                    .upload(dishImagePath!, data: dishData, options: .init(upsert: true))
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
                    logger.info("Pulled dietary preferences from server: \(prefs.map(\.displayName))")
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
