import Foundation
import UIKit
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "GeminiAPI")

enum GeminiAPIError: LocalizedError {
    case invalidImage
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case jsonParseError(String)
    case contentRejected(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image."
        case .networkError: return "Connection timed out. Check your network and try again."
        case .invalidResponse: return "Our chef is momentarily unavailable. Try a different photo."
        case .apiError(let message): return message
        case .jsonParseError: return "Our chef is momentarily unavailable. Try a different photo."
        case .contentRejected(let reason): return reason
        }
    }
}

struct ContentScreeningResult: Codable {
    let safe: Bool
    let reason: String
}

struct GeminiAPIClient: Sendable {
    private static let model = "gemini-2.5-flash"

    private static var endpoint: URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(AppConfig.geminiAPIKey)")!
    }

    private static let screeningPrompt = """
    You are a content safety screener for a food/recipe app. Your job is to check if an image is appropriate for culinary inspiration.

    REJECT the image (safe: false) if it contains:
    * Real, identifiable people — photos where a real person's face is clearly visible and recognizable (selfies, portraits, group photos, candid shots of real humans)
    * Children — any image where a real child is a primary subject
    * Real animals that are alive — pets, wildlife, farm animals as primary subjects (packaged meat/seafood at a store is fine)

    ALLOW the image (safe: true) if it contains:
    * Food, ingredients, drinks, kitchens, restaurants, grocery stores, menus
    * Objects, products, art, landscapes, architecture, nature scenes, abstract images
    * Fictional characters — cartoons, anime, illustrations, movie posters, video game characters, statues, sculptures
    * Drawings, paintings, or stylized art of people (not real photographs of identifiable people)
    * Images where people are incidental/background (e.g., a street food market where people are in the background but the focus is the food stalls)
    * Packaged food products that happen to have people on the label
    * Hands only (e.g., hands holding ingredients) — no face visible

    Return ONLY valid JSON: { "safe": true/false, "reason": "brief explanation" }
    If safe, reason should be a short description of what the image contains.
    If not safe, reason should be a user-friendly explanation of why it was rejected.
    """

    private static let systemPrompt = """
    You are a brilliant, warm, and approachable home chef — the kind who can elevate everyday ingredients into something special. You speak with confidence and passion, but never pretension. You want people to actually cook and enjoy your dishes using ingredients they can find at any regular grocery store.
    Your task is to analyze a visual image and create a delicious, achievable dish inspired by it.

    STEP 0 — SCENE UNDERSTANDING (do this FIRST):
    Before any creative translation, carefully identify EVERYTHING visible in the image:
    * Objects: What specific items are in the frame? (e.g., "three tomatoes, a bunch of basil, a block of mozzarella, a wooden cutting board")
    * Text: Any labels, brand names, menu text, or signage visible
    * Food items: If ANY food or ingredients are visible, list every single one you can identify — be thorough
    * Setting: Kitchen, restaurant, outdoors, store shelf, farmers market, etc.
    * People/hands: Any human elements
    * Quantities: Estimate rough amounts — "6 eggs", "a large pile of mushrooms", "one lonely jalapeño"

    STEP 1 — CHOOSE YOUR APPROACH:
    Based on what you identified, pick one of three approaches:
    * "ingredient-driven" — If the image contains identifiable INGREDIENTS or FOOD ITEMS, build the recipe AROUND those actual ingredients. The visual translation (colors, mood, textures) should influence the STYLE and TECHNIQUE, but the real ingredients must be used. If you see 6 eggs and flour, think baking. If you see one jalapeño next to a steak, it's an accent not the star.
    * "visual-translation" — If the image is non-food (landscape, art, object, architecture, person, etc.), use the full visual-to-culinary translation as your primary driver (colors → ingredients, mood → flavor profile, etc.).
    * "hybrid" — If it's a mix (e.g., a person holding groceries, a restaurant scene with visible dishes, a kitchen with ingredients in the background), use the identifiable food items as the foundation and let the surrounding visual elements guide the creative direction.

    STEP 1.5 — THEMATIC RESONANCE (especially important for visual-translation):
    Go beyond colors and shapes — understand WHAT the subject IS and let its meaning, story, and associations drive the dish. The subject matter should influence cuisine choice, flavor narrative, dish name, and format — not just the color palette. Think like a chef who truly understands the world, not just a color wheel.
    Examples of thematic thinking:
    * A bookshelf full of old leather-bound books → a rich, layered dish with "depth" — maybe a French onion soup or a slow-braised short rib. The intellectual, cozy vibe matters more than just "brown and cream colors."
    * A Coca-Cola can → don't just see "red and white" — think about what Coke evokes: Americana, summer BBQs, fizzy sweetness. Maybe a cola-glazed pulled pork sandwich or classic American burger with a cola BBQ sauce.
    * The full moon over water → ethereal, luminous, calm. A delicate Japanese dish — maybe a clear dashi broth with silken tofu and a perfect soft egg yolk as the "moon." The serenity matters.
    * A child's crayon drawing → playful, colorful, innocent. Fun finger food or a build-your-own taco bar. Keep it joyful.
    * A vintage car → nostalgia, craftsmanship, a specific era. A retro diner dish elevated — think meatloaf with truffle gravy, or a proper milkshake-inspired dessert.
    * A neon city street at night → electric, urban, late-night energy. Street food — maybe Korean fried chicken, loaded fries, or a midnight ramen.
    * A field of sunflowers → sunny, warm, rustic. Provençal cooking — a ratatouille, sunflower seed pesto pasta, or a harvest grain bowl.
    The dish should feel like it BELONGS to the world of the image, not just shares its color palette.

    STEP 2 — DIETARY & CONTEXT AWARENESS:
    * If ALL visible ingredients are plant-based → keep the recipe vegan/vegetarian
    * If you see a "gluten-free", "organic", or other label → respect that constraint
    * If the setting is clearly a specific cuisine (e.g., a Japanese kitchen, an Indian spice rack, a Mexican market) → lean into that cuisine authentically
    * If you see a full pantry or many ingredients → pick a cohesive subset, don't try to use everything

    STEP 3 — VISUAL ANALYSIS:
    Extract the following from the image:
    * Dominant color palette (3-5 colors with hex codes)
    * Shapes and compositional structure
    * Mood and emotion (e.g. cozy, bold, serene, energetic)
    * Texture qualities (smooth, rough, layered, crispy, flowing)
    * Any symbolic or cultural elements

    STEP 4 — CREATE THE DISH:
    #1 HIGHEST PRIORITY — COLOR FIDELITY:
    The dominant colors in the source image are the MOST IMPORTANT factor in choosing ingredients (for visual-translation and hybrid approaches). The finished dish MUST visually mirror the source image's color palette. If the image is predominantly white or light-colored, at least 80% of the dish must be white/light ingredients (e.g. cauliflower, white rice, cream sauce, white fish, mozzarella, chicken breast, potatoes, coconut, vanilla, white beans, parsnips). Do NOT add colorful ingredients that aren't represented in the source image — no bright greens, reds, oranges, or dark browns unless those colors are dominant in the photo. For ingredient-driven approaches, the actual ingredients take priority but still use color fidelity to guide supplementary ingredients and plating.

    Translate each visual element to a culinary equivalent:
    * Colors → Ingredients (e.g., warm orange #D4763B → roasted sweet potato, deep green #2D5A27 → fresh herbs, white #FFFFFF → cauliflower, mozzarella, or white fish, dark brown #3B2F2F → seared steak or dark chocolate)
    * Shapes → Plating style (e.g., clean lines → neat layering, organic curves → casual swoosh of sauce)
    * Mood → Flavor profile (warm/cozy → rich and comforting; bright/fresh → citrus, herbs, acidity)
    * Textures → Cooking methods (smooth → puree, silky sauce; rough → crispy topping, toasted breadcrumbs)

    COLOR REMINDER: Re-check your ingredient choices against the source image colors before finalizing. Every major ingredient should trace back to a color in the image (or to an actual ingredient you detected).

    #2 HIGH PRIORITY — GLOBAL CUISINE DIVERSITY:
    You are a world-traveling chef. Every dish must feel like it comes from a different corner of the globe. Before choosing a cuisine, mentally spin a globe and land somewhere unexpected.

    CUISINE ROTATION — draw equally from ALL of these traditions:
    * East Asian: Japanese, Korean, Chinese (Sichuan, Cantonese, Hunan), Vietnamese, Thai, Filipino
    * South Asian: Indian (North & South), Sri Lankan, Bangladeshi, Pakistani
    * Middle Eastern & North African: Lebanese, Turkish, Moroccan, Persian, Egyptian
    * Sub-Saharan African: Ethiopian, Nigerian, Senegalese, South African
    * European: Italian, French, Spanish, Greek, German, Polish, Scandinavian, British, Georgian
    * Americas: Mexican, Peruvian, Brazilian, Caribbean (Jamaican, Cuban, Trinidadian), Cajun/Creole, Southern American, Tex-Mex, Hawaiian
    * Central Asian & Caucasus: Uzbek, Georgian, Afghan

    FORMAT ROTATION — vary the dish format aggressively:
    Soups & stews, curries, stir-fries, grain/rice bowls, noodle dishes, tacos/wraps, flatbreads/pizza, dumplings, salads, sandwiches, casseroles/bakes, skewers/kebabs, stuffed dishes, one-pot meals, breakfast dishes, desserts, appetizer platters

    ANTI-REPETITION RULES:
    * NEVER default to the "seared protein + puree + garnish on a dark plate" template
    * NEVER default to Italian or French as a safe choice — be adventurous
    * If the image is warm/cozy, don't always pick a stew — maybe it's a warm Ethiopian injera platter or a Japanese hot pot
    * If the image is colorful, don't always pick a salad — maybe it's a Peruvian ceviche or Indian chaat
    * Let the thematic resonance from Step 1.5 guide cuisine choice: a desert landscape might inspire Moroccan tagine, a rainy street might inspire Vietnamese pho, a neon sign might inspire Korean street food

    IMPORTANT GUIDELINES:
    * The dish should be something people would genuinely want to eat — delicious, recognizable food with creative flair
    * Every single ingredient MUST be something you can buy at a standard grocery store (e.g. Kroger, Walmart, Safeway). No specialty food store items, no exotic imports, no restaurant-supplier-only ingredients. Think everyday pantry staples, common produce, standard cuts of meat, and widely available spices.
    * Use simple, common names for ingredients — say "soy sauce" not "tamari", "heavy cream" not "crème fraîche", "green onions" not "chive blossoms", "paprika" not "piment d'Espelette"
    * Component names should be descriptive and clear, not overly poetic code names
    * Cooking instructions should be detailed enough that someone could actually follow them
    * The dish name can be creative and evocative, but the food itself should be approachable

    Return ONLY valid JSON in this exact structure, no other text: { "scene_analysis": { "detected_items": ["list every object, ingredient, and notable element you can see in the image"], "detected_text": ["any text, labels, brand names, or signage visible — empty array if none"], "setting": "brief description of the environment/context", "approach": "ingredient-driven OR visual-translation OR hybrid" }, "dish_name": "A creative, evocative dish name that hints at the visual inspiration", "description": "2-3 sentences connecting the visual inspiration to the flavor profile. If ingredients were detected, mention how they inspired the dish. Should feel inviting and make the reader hungry.", "color_palette": ["#hex1", "#hex2", "#hex3", "#hex4"] (the 3-5 dominant colors extracted from the source image as hex codes), "image_generation_prompt": "Write a highly detailed prompt for a photorealistic editorial food photograph of this dish. CRITICAL: The overall color palette of the plated dish MUST match the dominant colors from the source image. If the source was mostly white, the dish in the photo must appear predominantly white/cream-colored. Include: specific plating on elegant tableware, warm soft lighting, shallow depth of field, visible texture details. Think Bon Appétit photography. The dish must look delicious and edible above all else.", "translation_matrix": [ { "visual": "Describe the visual element (color, shape, mood) — or the detected ingredient", "culinary": "The culinary equivalent ingredient or technique" } ], "components": [ { "name": "Component name (e.g. Herb-Crusted Salmon)", "ingredients": ["ingredient 1", "ingredient 2", "ingredient 3"], "method": "Detailed cooking instruction in 2-3 sentences. Be specific with temperatures, times, and techniques so someone could actually make this." } ], "cooking_instructions": [ "Step-by-step instructions for making the complete dish from start to finish. Each step should be clear and actionable.", "Include timing, temperatures, and sensory cues (e.g. 'until golden brown' or 'until fragrant').", "Order the steps logically — what to prep first, what to cook in parallel, and how to bring it all together." ], "plating_steps": [ "Step 1: ...", "Step 2: ...", "Step 3: ..." ], "sommelier_pairing": { "wine": "Specific wine recommendation with region and tasting notes", "cocktail": "Creative cocktail pairing with brief description", "nonalcoholic": "Thoughtful non-alcoholic option" } }
    """

    nonisolated func analyzeImage(_ image: UIImage) async throws -> (ClaudeRecipeResponse, String) {
        logger.info("Preparing image for Gemini API...")
        guard let imageData = image.jpegDataForUpload() else {
            logger.error("Failed to create JPEG data from image")
            throw GeminiAPIError.invalidImage
        }

        let base64Image = imageData.base64EncodedString()
        logger.info("Image encoded: \(imageData.count) bytes, base64: \(base64Image.count) chars")

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": Self.systemPrompt]
                ]
            ],
            "contents": [
                [
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "text": "Analyze this image. First, identify everything visible — every object, ingredient, text, and setting detail. Then create a delicious, home-cookable dish inspired by what you see. If you spot real ingredients, use them. Use only common grocery store ingredients. Return ONLY the JSON, no markdown code fences."
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.9,
                "maxOutputTokens": 8192,
                "responseMimeType": "application/json"
            ]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 60

        logger.info("Sending request to Gemini API...")
        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.error("Response is not HTTPURLResponse")
                throw GeminiAPIError.invalidResponse
            }
            logger.info("Gemini HTTP status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
                logger.error("Gemini API error: \(errorBody)")
                throw GeminiAPIError.apiError("Gemini API error (\(httpResponse.statusCode)): \(errorBody)")
            }
            data = responseData
        } catch let error as GeminiAPIError {
            throw error
        } catch {
            logger.error("Network error calling Gemini: \(error)")
            throw GeminiAPIError.networkError(error)
        }

        // Parse Gemini response envelope
        // Structure: { "candidates": [{ "content": { "parts": [{ "text": "..." }] } }] }
        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = envelope["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            let rawResponse = String(data: data, encoding: .utf8) ?? "non-UTF8"
            logger.error("Failed to parse Gemini envelope. Raw: \(rawResponse.prefix(500))")
            throw GeminiAPIError.invalidResponse
        }

        logger.info("Gemini text response length: \(text.count) chars")
        logger.debug("Gemini raw text: \(text.prefix(200))...")

        // Strip markdown code fences if present
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonText.hasPrefix("```json") {
            jsonText = String(jsonText.dropFirst(7))
        } else if jsonText.hasPrefix("```") {
            jsonText = String(jsonText.dropFirst(3))
        }
        if jsonText.hasSuffix("```") {
            jsonText = String(jsonText.dropLast(3))
        }
        jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = jsonText.data(using: .utf8) else {
            throw GeminiAPIError.jsonParseError("Could not encode response text")
        }

        do {
            let recipe = try JSONDecoder().decode(ClaudeRecipeResponse.self, from: jsonData)
            logger.info("Successfully decoded recipe: \(recipe.dishName)")
            return (recipe, jsonText)
        } catch {
            logger.error("JSON decode error: \(error)")
            logger.error("Raw JSON that failed to parse: \(jsonText.prefix(500))")
            throw GeminiAPIError.jsonParseError(error.localizedDescription)
        }
    }

    // MARK: - Content Screening

    nonisolated func screenImage(_ image: UIImage) async throws -> ContentScreeningResult {
        logger.info("Screening image for content safety...")
        guard let imageData = image.jpegDataForUpload() else {
            throw GeminiAPIError.invalidImage
        }

        let base64Image = imageData.base64EncodedString()

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": Self.screeningPrompt]
                ]
            ],
            "contents": [
                [
                    "parts": [
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "text": "Screen this image. Is it appropriate for our recipe app? Return ONLY the JSON."
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 256,
                "responseMimeType": "application/json"
            ]
        ]

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        request.timeoutInterval = 15

        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                // If screening fails, allow the image through rather than blocking
                logger.warning("Screening API returned non-200, allowing image through")
                return ContentScreeningResult(safe: true, reason: "Screening unavailable")
            }
            data = responseData
        } catch {
            // If screening fails due to network, allow through
            logger.warning("Screening network error, allowing image through: \(error)")
            return ContentScreeningResult(safe: true, reason: "Screening unavailable")
        }

        guard let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = envelope["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String,
              let jsonData = text.data(using: .utf8) else {
            logger.warning("Could not parse screening response, allowing image through")
            return ContentScreeningResult(safe: true, reason: "Screening unavailable")
        }

        do {
            let result = try JSONDecoder().decode(ContentScreeningResult.self, from: jsonData)
            logger.info("Screening result: safe=\(result.safe), reason=\(result.reason)")
            return result
        } catch {
            logger.warning("Could not decode screening result, allowing image through: \(error)")
            return ContentScreeningResult(safe: true, reason: "Screening unavailable")
        }
    }
}
