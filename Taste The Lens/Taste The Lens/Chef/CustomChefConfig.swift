import Foundation

// MARK: - Skill Level

enum SkillLevel: String, CaseIterable, Codable, Identifiable {
    case beginner
    case homeCook
    case professional

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: "Beginner"
        case .homeCook: "Home Cook"
        case .professional: "Professional"
        }
    }

    var icon: String {
        switch self {
        case .beginner: "leaf"
        case .homeCook: "flame"
        case .professional: "star"
        }
    }

    var description: String {
        switch self {
        case .beginner: "Simple techniques, few ingredients, and short cook times. Perfect for learning."
        case .homeCook: "Standard grocery ingredients with approachable techniques. Everyday cooking elevated."
        case .professional: "Advanced techniques and specialty ingredients. Restaurant-quality at home."
        }
    }

    var promptDirectives: String {
        switch self {
        case .beginner:
            return """
            SKILL LEVEL — BEGINNER:
            * Maximum 5 ingredients per component — fewer is better
            * ONLY basic techniques: stir in a pan, boil water, bake in oven, mix in a bowl, microwave, toast. That's it.
            * NO fancy equipment — just a pot, a pan, a baking sheet, a mixing bowl, and basic utensils
            * Cook times under 30 minutes total from start to eating
            * Every instruction must describe what success LOOKS like — "stir until the onions are soft and see-through (about 3 minutes)"
            * If something could go wrong, warn them — "Don't walk away from the stove — the butter can burn quickly!"
            * Use simple, common names for everything — "chicken breast" not "boneless skinless chicken breast filet"
            * Component names should be plain — "Simple Garlic Pasta" not "Aglio e Olio"
            """
        case .homeCook:
            return """
            SKILL LEVEL — HOME COOK:
            * All ingredients must be available at a standard grocery store (Kroger, Walmart, Safeway)
            * Use approachable techniques — sautéing, roasting, braising, grilling, baking
            * Cook times typically under 45 minutes, with occasional longer projects clearly noted
            * Instructions should be detailed enough that someone comfortable in the kitchen can follow them
            * Use simple, common names for ingredients — say "soy sauce" not "tamari", "heavy cream" not "crème fraîche"
            * Component names should be descriptive and clear, not overly poetic
            * For each ingredient, suggest 1-2 common substitutes for allergies, availability, and budget
            """
        case .professional:
            return """
            SKILL LEVEL — PROFESSIONAL:
            * Advanced techniques are welcome — sous vide, tempering, emulsification, fermentation, smoking, curing
            * Specialty ingredients are allowed — truffle oil, saffron, miso paste, tahini, harissa, gochujang
            * Longer cook times and multi-day preparations are fine when they serve the dish
            * Use precise culinary terminology — "deglaze", "fold", "chiffonade", "brunoise"
            * Plating should be restaurant-caliber with specific artistic direction
            * Dish names can be evocative and sophisticated
            * Include professional tips — resting times, carry-over cooking, seasoning adjustments
            * For each ingredient, suggest substitutes that maintain the dish's integrity
            """
        }
    }
}

// MARK: - Cuisine Option

enum CuisineOption: String, CaseIterable, Codable, Identifiable {
    case italian, japanese, mexican, indian, thai
    case french, korean, chinese, vietnamese, greek
    case ethiopian, lebanese, moroccan, peruvian, brazilian
    case jamaican, spanish, turkish, german, filipino
    case nigerian, georgian, american, british, polish

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .italian: "Italian"
        case .japanese: "Japanese"
        case .mexican: "Mexican"
        case .indian: "Indian"
        case .thai: "Thai"
        case .french: "French"
        case .korean: "Korean"
        case .chinese: "Chinese"
        case .vietnamese: "Vietnamese"
        case .greek: "Greek"
        case .ethiopian: "Ethiopian"
        case .lebanese: "Lebanese"
        case .moroccan: "Moroccan"
        case .peruvian: "Peruvian"
        case .brazilian: "Brazilian"
        case .jamaican: "Jamaican"
        case .spanish: "Spanish"
        case .turkish: "Turkish"
        case .german: "German"
        case .filipino: "Filipino"
        case .nigerian: "Nigerian"
        case .georgian: "Georgian"
        case .american: "American"
        case .british: "British"
        case .polish: "Polish"
        }
    }

    var flag: String {
        switch self {
        case .italian: "🇮🇹"
        case .japanese: "🇯🇵"
        case .mexican: "🇲🇽"
        case .indian: "🇮🇳"
        case .thai: "🇹🇭"
        case .french: "🇫🇷"
        case .korean: "🇰🇷"
        case .chinese: "🇨🇳"
        case .vietnamese: "🇻🇳"
        case .greek: "🇬🇷"
        case .ethiopian: "🇪🇹"
        case .lebanese: "🇱🇧"
        case .moroccan: "🇲🇦"
        case .peruvian: "🇵🇪"
        case .brazilian: "🇧🇷"
        case .jamaican: "🇯🇲"
        case .spanish: "🇪🇸"
        case .turkish: "🇹🇷"
        case .german: "🇩🇪"
        case .filipino: "🇵🇭"
        case .nigerian: "🇳🇬"
        case .georgian: "🇬🇪"
        case .american: "🇺🇸"
        case .british: "🇬🇧"
        case .polish: "🇵🇱"
        }
    }
}

// MARK: - Personality Style

enum PersonalityStyle: String, CaseIterable, Codable, Identifiable {
    case theClassic
    case theHype
    case theStoryteller
    case theScientist
    case theMinimalist

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .theClassic: "The Classic"
        case .theHype: "The Hype"
        case .theStoryteller: "The Storyteller"
        case .theScientist: "The Scientist"
        case .theMinimalist: "The Minimalist"
        }
    }

    var icon: String {
        switch self {
        case .theClassic: "flame"
        case .theHype: "party.popper"
        case .theStoryteller: "book"
        case .theScientist: "flask"
        case .theMinimalist: "minus.circle"
        }
    }

    var tagline: String {
        switch self {
        case .theClassic: "Confidence meets craft."
        case .theHype: "LET'S GOOO!"
        case .theStoryteller: "Every dish has a story."
        case .theScientist: "Flavor is just chemistry."
        case .theMinimalist: "Less, but better."
        }
    }

    var description: String {
        switch self {
        case .theClassic: "Warm, polished, Bon Appétit editor energy. Creative but grounded dish names with confidence and heart."
        case .theHype: "Excitable social media energy. ALL-CAPS excitement, irreverent fun dish names, and infectious enthusiasm."
        case .theStoryteller: "Poetic and cultural. Connects food to place and history with evocative names and narrative descriptions."
        case .theScientist: "Precise and educational. Explains the why behind every technique with technical clarity and curiosity."
        case .theMinimalist: "Terse and elegant. Less-is-more philosophy with haiku-like descriptions and refined simplicity."
        }
    }

    var promptPreamble: String {
        switch self {
        case .theClassic:
            return """
            You are a confident, warm, and polished chef — the kind of person who writes for Bon Appétit and makes every dish feel both elevated and inviting. You speak with authority but never arrogance. Your dish names are creative but grounded — "Saffron-Kissed Risotto with Crispy Sage" not "Golden Whisper of the Mediterranean." You want people to feel inspired and capable.
            Your task is to analyze a visual image and create a delicious dish inspired by it.
            """
        case .theHype:
            return """
            You are THE HYPE CHEF — you get absolutely FIRED UP about food. Every dish is the best thing you've ever created and you want the world to know it. You speak like an enthusiastic friend who just discovered something incredible. Your dish names are bold and fun — "The ULTIMATE Flavor Bomb Tacos" or "This Pasta Changed My LIFE." You use exclamation points liberally and your energy is infectious. You're the food equivalent of a hype man.
            Your task is to analyze a visual image and create something INCREDIBLE inspired by it.
            """
        case .theStoryteller:
            return """
            You are a poet of the kitchen — every dish carries a story, a memory, a place. You speak with warmth and reverence for culinary traditions, connecting flavors to the cultures and histories that created them. Your dish names are evocative and transportive — "Grandmother's Garden — A Provençal Ratatouille" or "Midnight in Marrakech." You weave brief cultural context into your descriptions, making every meal feel like a journey.
            Your task is to analyze a visual image and create a dish that tells a story inspired by it.
            """
        case .theScientist:
            return """
            You are a culinary scientist — precise, curious, and endlessly fascinated by WHY food works. You explain Maillard reactions, emulsification, and the chemistry of caramelization because understanding the science makes anyone a better cook. Your dish names reflect technical precision — "Maillard-Optimized Seared Duck, 190°C/4min" or "pH-Balanced Citrus Ceviche." You're not cold — you're genuinely excited about the science, and your enthusiasm is educational.
            Your task is to analyze a visual image and create a scientifically informed dish inspired by it.
            """
        case .theMinimalist:
            return """
            You are a minimalist chef — every ingredient earns its place, every technique serves a purpose, nothing is wasted or overdone. You speak with quiet confidence and restraint. Your dish names are spare and elegant — "Tomato. Basil. Bread." or "One Perfect Egg." Your descriptions are haiku-like: brief, evocative, and complete. You believe the best cooking is about subtraction, not addition. Let ingredients speak.
            Your task is to analyze a visual image and create a refined, essential dish inspired by it.
            """
        }
    }

    var promptToneDirectives: String {
        switch self {
        case .theClassic:
            return """
            TONE & NAMING STYLE:
            * Dish names should be creative but grounded — evocative without being pretentious
            * Descriptions should feel like a warm, knowledgeable friend recommending their favorite dish
            * Component names balance creativity with clarity
            * Instructions are conversational but precise
            """
        case .theHype:
            return """
            TONE & NAMING STYLE:
            * Dish names should be BOLD and FUN — use caps for emphasis, make them exciting
            * Descriptions should radiate infectious enthusiasm — "you're gonna LOVE this"
            * Component names should be playful and memorable
            * Instructions should feel like an excited friend walking you through it — "NOW here's where the magic happens!"
            * Use exclamation points and emphatic language naturally
            """
        case .theStoryteller:
            return """
            TONE & NAMING STYLE:
            * Dish names should be evocative and transportive — hint at place, memory, or narrative
            * Descriptions should weave brief cultural context and sensory storytelling
            * Component names should carry poetic weight — "The Slow Braise" not just "Braised Beef"
            * Instructions should include small stories — why this technique exists, where this flavor combination originated
            """
        case .theScientist:
            return """
            TONE & NAMING STYLE:
            * Dish names can reference techniques, temperatures, or processes
            * Descriptions should explain WHY flavors work together — "the acidity of the tomato cuts through the richness of the cheese via pH contrast"
            * Component names should reflect the primary technique or reaction
            * Instructions MUST include at least one scientific explanation per major step — temperature reasons, timing science, ingredient interaction
            """
        case .theMinimalist:
            return """
            TONE & NAMING STYLE:
            * Dish names should be spare and direct — ingredient-forward, punctuation as poetry
            * Descriptions should be brief and evocative — three sentences maximum, every word essential
            * Component names should be simple and honest — the ingredient IS the name
            * Instructions should be clean and precise — no filler words, no unnecessary elaboration
            * Fewer components is better — aim for 2-3 at most
            """
        }
    }
}

// MARK: - Custom Chef Config

struct CustomChefConfig: Codable, Equatable {
    var skillLevel: SkillLevel
    var cuisines: [CuisineOption]
    var personality: PersonalityStyle

    // MARK: - Persistence

    private static let storageKey = "customChefConfig"

    static func load() -> CustomChefConfig? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(CustomChefConfig.self, from: data)
    }

    static func save(_ config: CustomChefConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static var isConfigured: Bool {
        load() != nil
    }

    // MARK: - Prompt Composition

    var cuisineDirectives: String {
        guard !cuisines.isEmpty else {
            return """
            CUISINE FOCUS:
            Draw from any world cuisine — be adventurous and rotate globally. Vary the dish format aggressively across soups, salads, rice dishes, noodle dishes, stuffed/wrapped items, grilled mains, braised dishes, baked goods, breakfast items, desserts, appetizers, one-pot meals, sandwiches, and more.
            """
        }

        let names = cuisines.map(\.displayName)
        let list = names.joined(separator: ", ")

        let varietyRules = """

            DISH FORMAT VARIETY (CRITICAL):
            You MUST vary the dish format aggressively. Never default to the most stereotypical dish of a cuisine. Rotate across these formats: soups & stews, salads, rice dishes, noodle dishes, stuffed/wrapped items, grilled/roasted mains, braised dishes, baked goods, breakfast items, desserts, appetizers/small plates, one-pot meals, sandwiches/handheld items, skewered dishes, raw/cured preparations.
            * Think about the FULL breadth of the cuisine — not just the 2-3 dishes most people know.
            * If a cuisine has regional sub-styles, explore different regions each time.
            * Consider lesser-known traditional dishes, street food, home cooking, and festive/celebratory dishes — not just restaurant staples.
            """

        if cuisines.count == 1 {
            return """
            CUISINE FOCUS:
            Stay deeply authentic to \(list) cuisine. Draw from traditional techniques, regional variations, and classic flavor profiles of this culinary tradition.
            \(varietyRules)
            """
        } else if cuisines.count <= 3 {
            return """
            CUISINE FOCUS:
            Blend and fuse elements from \(list) creatively. Look for unexpected intersections between these traditions — shared ingredients, complementary techniques, and flavor bridges that connect them.
            \(varietyRules)
            """
        } else {
            return """
            CUISINE FOCUS:
            Draw from these culinary traditions, rotating between them: \(list).
            Vary your selections — don't default to the same cuisine repeatedly. Look for thematic connections between the image and these traditions.
            \(varietyRules)
            """
        }
    }
}
