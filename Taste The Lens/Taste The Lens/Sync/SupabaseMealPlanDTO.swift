import Foundation

/// Codable DTO mirroring the Supabase `meal_plans` table. Mirrors the
/// SupabaseRecipeDTO pattern (snake_case columns, from/to helpers).
struct SupabaseMealPlanDTO: Codable {
    let id: String?
    let userId: String
    let chef: String?
    let title: String
    let daysCount: Int
    let mealsPerDay: Int
    let groceryList: [GroceryItem]?
    let isDeleted: Bool?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case chef
        case title
        case daysCount = "days_count"
        case mealsPerDay = "meals_per_day"
        case groceryList = "grocery_list"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func from(plan: MealPlan, userId: String) -> SupabaseMealPlanDTO {
        SupabaseMealPlanDTO(
            id: plan.remoteId,
            userId: userId,
            chef: plan.chefPersonality,
            title: plan.title,
            daysCount: plan.daysCount,
            mealsPerDay: plan.mealsPerDay,
            groceryList: plan.groceryList,
            isDeleted: plan.isDeleted,
            createdAt: nil,
            updatedAt: nil
        )
    }

    /// Build a transient (not-inserted) MealPlan from the DTO + already-hydrated meals.
    func toMealPlan(meals: [PlannedMeal]) -> MealPlan {
        let plan = MealPlan(
            title: title,
            chefPersonality: chef,
            daysCount: daysCount,
            mealsPerDay: mealsPerDay,
            groceryList: groceryList ?? [],
            meals: meals,
            userId: userId
        )
        plan.remoteId = id
        plan.syncStatus = "synced"
        for meal in meals { meal.plan = plan }
        return plan
    }
}
