import Foundation

enum IngredientCategory: String, CaseIterable {
    case produce = "Produce"
    case protein = "Protein & Seafood"
    case dairy = "Dairy & Eggs"
    case pantry = "Pantry Staples"
    case spices = "Spices & Seasonings"
    case other = "Other"

    var emoji: String {
        switch self {
        case .produce: return "\u{1F96C}" // leafy green
        case .protein: return "\u{1F969}" // cut of meat
        case .dairy: return "\u{1F95B}" // glass of milk
        case .pantry: return "\u{1FAD9}" // jar
        case .spices: return "\u{1F9C2}" // salt
        case .other: return "\u{1F6D2}" // shopping cart
        }
    }
}

enum ShoppingListGenerator {

    static func generate(from recipe: Recipe, servingCount: Int) -> String {
        var categorized: [IngredientCategory: [String]] = [:]
        var totalCount = 0

        for component in recipe.components {
            for ingredient in component.ingredients {
                let parsed = IngredientParser.parse(ingredient)
                let scaled = parsed.scaled(from: recipe.baseServings, to: servingCount)
                let category = categorize(parsed.name)
                categorized[category, default: []].append(scaled)
                totalCount += 1
            }
        }

        var lines: [String] = []

        // Header
        lines.append("\u{1F37D}\u{FE0F} \(recipe.dishName)")
        lines.append("\u{1F4CB} Shopping List \u{00B7} \(servingCount) servings \u{00B7} \(totalCount) items")
        lines.append(String(repeating: "\u{2500}", count: 32))

        for category in IngredientCategory.allCases {
            guard let items = categorized[category], !items.isEmpty else { continue }
            lines.append("")
            lines.append("\(category.emoji) \(category.rawValue.uppercased())")
            for item in items {
                lines.append("   \u{25CB} \(item)")
            }
        }

        lines.append("")
        lines.append(String(repeating: "\u{2500}", count: 32))
        lines.append("Made with Taste The Lens")

        return lines.joined(separator: "\n")
    }

    private static func categorize(_ name: String) -> IngredientCategory {
        let lower = name.lowercased()

        let produce = [
            "lettuce", "tomato", "onion", "garlic", "carrot", "pepper", "herb",
            "basil", "cilantro", "lemon", "lime", "orange", "apple", "banana",
            "potato", "sweet potato", "mushroom", "spinach", "kale", "arugula",
            "zucchini", "squash", "broccoli", "cauliflower", "celery", "cucumber",
            "avocado", "corn", "pea", "bean sprout", "cabbage", "radish",
            "beet", "turnip", "parsnip", "leek", "shallot", "scallion",
            "green onion", "ginger", "jalapeño", "chili", "chile", "serrano",
            "habanero", "poblano", "bell pepper", "eggplant", "fennel",
            "asparagus", "artichoke", "bok choy", "watercress", "mint",
            "parsley", "dill", "chive", "rosemary", "thyme", "sage",
            "oregano", "tarragon", "lemongrass", "berry", "strawberry",
            "blueberry", "raspberry", "mango", "pineapple", "peach",
            "pear", "plum", "grape", "melon", "watermelon", "coconut",
            "fig", "date", "pomegranate", "kiwi", "passion fruit",
        ]

        let protein = [
            "chicken", "beef", "pork", "lamb", "turkey", "duck", "veal",
            "venison", "bison", "rabbit", "fish", "salmon", "tuna", "cod",
            "halibut", "tilapia", "trout", "shrimp", "prawn", "crab",
            "lobster", "scallop", "mussel", "clam", "oyster", "squid",
            "octopus", "anchovy", "sardine", "tofu", "tempeh", "seitan",
            "sausage", "bacon", "ham", "prosciutto", "pancetta",
            "ground meat", "steak", "ribs", "breast", "thigh", "wing",
        ]

        let dairy = [
            "milk", "cream", "cheese", "butter", "yogurt", "egg",
            "sour cream", "crème fraîche", "creme fraiche", "mascarpone",
            "ricotta", "mozzarella", "parmesan", "cheddar", "gruyère",
            "gruyere", "brie", "gouda", "feta", "goat cheese",
            "cream cheese", "half-and-half", "whipping cream", "ghee",
            "buttermilk", "cottage cheese",
        ]

        let spices = [
            "salt", "pepper", "cumin", "paprika", "cinnamon", "nutmeg",
            "clove", "cardamom", "coriander", "turmeric", "chili powder",
            "cayenne", "red pepper flakes", "black pepper", "white pepper",
            "allspice", "star anise", "anise", "bay leaf", "saffron",
            "mustard seed", "fennel seed", "caraway", "sumac", "za'atar",
            "garam masala", "curry powder", "five spice", "smoked paprika",
            "onion powder", "garlic powder", "seasoning",
        ]

        let pantryItems = [
            "oil", "olive oil", "vegetable oil", "sesame oil", "coconut oil",
            "flour", "sugar", "brown sugar", "powdered sugar", "honey",
            "maple syrup", "molasses", "rice", "pasta", "noodle",
            "soy sauce", "vinegar", "worcestershire", "hot sauce",
            "ketchup", "mustard", "mayonnaise", "sriracha", "tahini",
            "peanut butter", "almond butter", "jam", "broth", "stock",
            "tomato paste", "tomato sauce", "canned tomato", "coconut milk",
            "cornstarch", "baking powder", "baking soda", "yeast",
            "vanilla", "cocoa", "chocolate", "breadcrumb", "panko",
            "tortilla", "bread", "pita", "naan", "cracker",
            "nut", "almond", "walnut", "pecan", "cashew", "pistachio",
            "pine nut", "sesame seed", "sunflower seed", "pumpkin seed",
            "dried", "canned", "lentil", "chickpea", "black bean",
            "kidney bean", "white bean", "quinoa", "couscous", "oat",
            "wine", "beer", "mirin", "sake", "fish sauce",
        ]

        for keyword in spices {
            if lower.contains(keyword) { return .spices }
        }
        for keyword in dairy {
            if lower.contains(keyword) { return .dairy }
        }
        for keyword in protein {
            if lower.contains(keyword) { return .protein }
        }
        for keyword in produce {
            if lower.contains(keyword) { return .produce }
        }
        for keyword in pantryItems {
            if lower.contains(keyword) { return .pantry }
        }

        return .other
    }
}
