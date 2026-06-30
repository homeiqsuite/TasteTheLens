import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;

// OpenAI flagship text model used for researched meal-plan generation.
// (Balanced tier — strong quality at ~$2.50/$15 per 1M tokens.)
const OPENAI_TEXT_MODEL = "gpt-5.4";

const MAX_MEALS = 28; // 7 days × up to 4 meals

// ─── Request / Response Types ───────────────────────────────────────────────

interface GenerateMealPlanRequest {
  chef: string;
  customChefConfig?: {
    skillLevel: string;
    cuisines: string[];
    personality: string;
  };
  dietaryPreferences?: string[];
  daysCount: number;
  mealTypes: string[]; // e.g. ["Breakfast","Lunch","Dinner"]
  servings: number;
  budgetLimit?: number;
  caloriesPerMeal?: number; // target calories per serving for each meal
  skillLevel?: string;
  excludeDishes?: string[]; // dishes already in the user's library — never repeat these
}

// ─── Chef Personas (meal-plan flavored) ─────────────────────────────────────
// Each persona carries the chef identity, a meal-plan philosophy, and a
// RESEARCH FOCUS that tells the model what to actually look up online.

interface ChefPersona {
  identity: string;
  research: string;
  rules: string;
}

const CHEF_PERSONAS: Record<string, ChefPersona> = {
  default: {
    identity:
      "You are The Chef — a warm, world-traveling home cook who turns everyday grocery-store ingredients into a globally diverse week of meals.",
    research:
      "current seasonal produce, well-loved balanced weeknight dinners, and globally varied home-cooking recipes",
    rules:
      "Rotate cuisines aggressively across the week (no repeats). Every ingredient must be available at a standard grocery store.",
  },
  dooby: {
    identity:
      "You are Dooby — the late-night comfort-food genius. Your week is loaded, indulgent, and fun, but still cookable at home.",
    research:
      "trending comfort-food mashups, loaded snack formats, and crowd-favorite indulgent recipes",
    rules:
      "Lean into loaded, cheesy, crunchy comfort food. Vary formats (no fries more than once). Keep it achievable.",
  },
  beginner: {
    identity:
      "You are The Beginner's Chef — a patient mentor. Every meal this week is dead-simple with minimal ingredients and basic techniques.",
    research:
      "easy beginner-friendly recipes, 5-ingredient meals, and no-fail weeknight dinners",
    rules:
      "Max 5 ingredients per component. Only basic techniques (boil, pan-fry, bake, mix, microwave, toast). Under 30 min per meal.",
  },
  grizzly: {
    identity:
      "You are Grizzly — a field-to-table outdoor cook. Your week honors hearty, rustic cooking with game and whole-animal thinking.",
    research:
      "game meat cooking techniques, rustic outdoor recipes, and seasonal hearty meals",
    rules:
      "Favor rustic, hearty dishes. Always provide a common grocery-store protein substitute for any game meat.",
  },
  family: {
    identity:
      "You are Big & Little Chef — a parent + child cooking duo. Every meal is family-friendly and kid-approved.",
    research:
      "kid-friendly family dinners, recipes children love, and meals families can cook together",
    rules:
      "Kid-friendly, colorful, familiar dishes. Keep each meal under 45 minutes and manageable for cooking with children.",
  },
  healthy: {
    identity:
      "You are The Nutritionist — a chef and nutrition expert. Every meal this week is balanced, whole-food, and genuinely nutritious without feeling like diet food.",
    research:
      "evidence-based balanced macronutrient meals, anti-inflammatory whole foods, and current nutrition guidance for healthy eating",
    rules:
      "Each meal must balance lean protein, complex carbs, and healthy fats with vegetables as the centerpiece. Nutrition numbers must be realistic and well-estimated. Favor anti-inflammatory, fiber-rich, antioxidant-dense ingredients.",
  },
  gerd: {
    identity:
      "You are The Healer — a chef specializing in GERD (acid reflux) and LPR (silent reflux) cooking. Every meal this week is gentle, low-acid, and low-fat.",
    research:
      "evidence-based GERD and LPR safe foods, reflux trigger foods to avoid, low-acid diet guidance, and soothing reflux-friendly recipes",
    rules:
      "ABSOLUTELY NO reflux triggers anywhere in the plan: tomatoes/tomato products, citrus, vinegar, wine/alcohol, spicy peppers/hot sauce, excessive black pepper, raw onion & raw garlic, mint, chocolate, coffee/caffeine, carbonation, deep-fried/high-fat foods, full-fat dairy. Use gentle methods only (steam, poach, bake, simmer, light sauté). For each meal, the research_notes must briefly explain why it is reflux-safe.",
  },
  plantbased: {
    identity:
      "You are The Botanist — a devoted plant-based chef. Every meal this week is 100% vegan, protein-complete, and bursting with flavor.",
    research:
      "complete plant protein combinations, high-protein vegan meals, and globally diverse plant-based recipes",
    rules:
      "EVERY ingredient must be vegan — zero animal products (no meat, fish, eggs, dairy, honey, gelatin). Build complete proteins by combining legumes, soy, whole grains, nuts and seeds. Note approximate plant-protein grams per serving in research_notes.",
  },
  lowfodmap: {
    identity:
      "You are The Gut Guide — a chef specializing in the low-FODMAP diet for IBS and sensitive digestion. Every meal this week is gentle on the gut while staying full of flavor.",
    research:
      "Monash University low-FODMAP food lists, low-FODMAP serving sizes, IBS-friendly recipes, and high-FODMAP triggers to avoid",
    rules:
      "ABSOLUTELY NO high-FODMAP triggers: garlic or onion (incl. leek/shallot bulbs), wheat-based bread/pasta, most legumes, high-fructose fruits (apple, pear, mango, watermelon, cherries), honey, agave, high-lactose dairy, cashews, pistachios, sugar alcohols. Use garlic-infused oil and scallion/chive green tops for allium flavor. Keep portions within low-FODMAP limits. In research_notes, briefly note why each meal is low-FODMAP.",
  },
  alkaline: {
    identity:
      "You are The Alkalist — a vibrant, plant-forward chef devoted to the alkaline diet. Every meal this week is built around alkalizing whole foods and minimizes acid-forming ingredients.",
    research:
      "alkaline diet food lists, alkalizing vs acid-forming foods, PRAL values, and fresh plant-forward alkaline recipes",
    rules:
      "Center each meal on alkalizing whole foods (leafy greens, vegetables, avocado, almonds, seeds, herbs, lemon/lime, berries, melon). Minimize strongly acid-forming foods (red & processed meat, refined sugar, refined grains, excess dairy). Plant-forward — fish or a modest milder protein is okay, but vegetables lead. Favor fresh, raw, lightly steamed, roasted, or blended preparations.",
  },
};

function personaFor(req: GenerateMealPlanRequest): ChefPersona {
  if (req.chef === "custom" && req.customChefConfig) {
    const cuisines = req.customChefConfig.cuisines?.length
      ? req.customChefConfig.cuisines.join(", ")
      : "global";
    return {
      identity: `You are a custom personal chef cooking a ${req.customChefConfig.skillLevel} skill-level week focused on ${cuisines} cuisine.`,
      research: `${cuisines} recipes, balanced weekly meal ideas, and seasonal ingredients`,
      rules:
        "Honor the requested cuisines and skill level. Every ingredient must be available at a standard grocery store.",
    };
  }
  return CHEF_PERSONAS[req.chef] ?? CHEF_PERSONAS["default"];
}

const DIETARY_DISPLAY_NAMES: Record<string, string> = {
  vegetarian: "Vegetarian", vegan: "Vegan", pescatarian: "Pescatarian",
  "gluten-free": "Gluten-Free", "dairy-free": "Dairy-Free", "nut-free": "Nut-Free",
  keto: "Keto", "low-carb": "Low-Carb", halal: "Halal", kosher: "Kosher",
};

function buildSystemPrompt(req: GenerateMealPlanRequest): string {
  const persona = personaFor(req);
  const totalMeals = req.daysCount * req.mealTypes.length;
  const mealTypeList = req.mealTypes.join(", ");

  let prompt = `${persona.identity}

You are creating a complete ${req.daysCount}-day meal plan with these meals each day: ${mealTypeList}. That is exactly ${totalMeals} meals total, each sized for ${req.servings} serving(s).

EXPERTISE & RESEARCH NOTES:
Draw on your deep culinary and nutrition expertise about ${persona.research}. Do NOT search the web. For each meal, set "research_notes" to a 1-sentence, genuinely useful insight (a nutrition fact, a technique tip, or why the dish fits this style). Set "sources" to an empty array unless you are citing a widely-known, real reference.

YOUR RULES:
${persona.rules}

PLAN REQUIREMENTS:
* Produce EXACTLY ${totalMeals} meals — one for each (day, meal type) pair, days numbered 1..${req.daysCount}.
* Across the week, avoid repeating the same dish. Aim for variety while reusing overlapping ingredients so the grocery list stays efficient and affordable.
* Each meal includes full recipe detail: components (each ingredient prefixed with a numeric quantity + unit, e.g. "2 tbsp olive oil"), exactly 4 cooking_steps each with a practical tip, realistic per-serving nutrition, and an image_generation_prompt describing a photorealistic editorial food photo of the finished dish.
* substitutions.original MUST exactly match the corresponding ingredient string.
* difficulty is one of "Easy", "Medium", "Advanced".

GROCERY LIST:
* Produce a single consolidated "grocery_list" covering the WHOLE plan. Sum quantities of the same ingredient across all meals, and group each item by supermarket aisle (e.g. "Produce", "Meat & Seafood", "Dairy", "Pantry", "Frozen", "Bakery", "Spices").`;

  if (req.dietaryPreferences && req.dietaryPreferences.length > 0) {
    const list = req.dietaryPreferences.map((p) => DIETARY_DISPLAY_NAMES[p] || p).join(", ");
    prompt += `\n\nCRITICAL DIETARY CONSTRAINTS: EVERY meal MUST comply with ALL of: ${list}. Never include an ingredient that violates these.`;
  }

  if (req.budgetLimit != null) {
    const formatted = req.budgetLimit % 1 === 0 ? `$${req.budgetLimit}` : `$${req.budgetLimit.toFixed(2)}`;
    prompt += `\n\nBUDGET CONSTRAINT: Keep the total grocery cost for the entire ${req.daysCount}-day plan under ${formatted}. Favor affordable staples, in-season produce, and cost-effective proteins. Reuse ingredients across meals to minimize waste.`;
  }

  if (req.caloriesPerMeal != null && req.caloriesPerMeal > 0) {
    prompt += `\n\nCALORIE TARGET (MANDATORY): Each meal MUST be approximately ${req.caloriesPerMeal} calories per serving — stay within ±10% (${Math.round(req.caloriesPerMeal * 0.9)}–${Math.round(req.caloriesPerMeal * 1.1)} kcal). Adjust portion sizes, ingredient amounts, and preparation to hit this target. The "nutrition.calories" value for every meal MUST reflect the actual recipe and land in that range.`;
  }

  if (req.skillLevel && req.chef !== "custom") {
    prompt += `\n\nSKILL LEVEL: Target a "${req.skillLevel}" home cook — adjust technique complexity accordingly.`;
  }

  if (req.excludeDishes && req.excludeDishes.length > 0) {
    const list = req.excludeDishes.slice(0, 80).join("; ");
    prompt += `\n\nAVOID REPEATS (IMPORTANT): The user already has these dishes in their library. Do NOT generate any of them or a close variation — create entirely new, distinct dishes (different proteins, formats, and cuisines): ${list}.`;
  }

  return prompt;
}

// ─── Structured Output Schema ───────────────────────────────────────────────

const MEAL_PLAN_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    title: { type: "string" },
    meals: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          day: { type: "integer" },
          meal_type: { type: "string" },
          dish_name: { type: "string" },
          description: { type: "string" },
          research_notes: { type: "string" },
          sources: { type: "array", items: { type: "string" } },
          prep_time: { type: "string" },
          cook_time: { type: "string" },
          difficulty: { type: "string" },
          color_palette: { type: "array", items: { type: "string" } },
          image_generation_prompt: { type: "string" },
          components: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                name: { type: "string" },
                ingredients: { type: "array", items: { type: "string" } },
                substitutions: {
                  type: "array",
                  items: {
                    type: "object",
                    additionalProperties: false,
                    properties: {
                      original: { type: "string" },
                      substitutes: { type: "array", items: { type: "string" } },
                    },
                    required: ["original", "substitutes"],
                  },
                },
                method: { type: "string" },
              },
              required: ["name", "ingredients", "substitutions", "method"],
            },
          },
          cooking_steps: {
            type: "array",
            items: {
              type: "object",
              additionalProperties: false,
              properties: {
                instruction: { type: "string" },
                ingredients_used: { type: "array", items: { type: "string" } },
                tip: { type: "string" },
              },
              required: ["instruction", "ingredients_used", "tip"],
            },
          },
          nutrition: {
            type: "object",
            additionalProperties: false,
            properties: {
              calories: { type: "integer" },
              protein: { type: "integer" },
              carbs: { type: "integer" },
              fat: { type: "integer" },
              fiber: { type: "integer" },
              sugar: { type: "integer" },
            },
            required: ["calories", "protein", "carbs", "fat", "fiber", "sugar"],
          },
        },
        required: [
          "day", "meal_type", "dish_name", "description", "research_notes",
          "sources", "prep_time", "cook_time", "difficulty", "color_palette",
          "image_generation_prompt", "components", "cooking_steps", "nutrition",
        ],
      },
    },
    grocery_list: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          name: { type: "string" },
          quantity: { type: "string" },
          aisle: { type: "string" },
        },
        required: ["name", "quantity", "aisle"],
      },
    },
  },
  required: ["title", "meals", "grocery_list"],
};

// ─── OpenAI Responses API ────────────────────────────────────────────────────
// Single no-search generation call with zero reasoning effort, so a full plan
// reliably finishes well under the 150s edge-function wall-clock limit. Research
// notes come from the model's built-in culinary/nutrition knowledge.

/** Extracts the aggregated output_text from a Responses API payload. */
function extractOutputText(data: Record<string, unknown>): string {
  if (typeof data.output_text === "string" && data.output_text.length > 0) {
    return data.output_text as string;
  }
  let text = "";
  if (Array.isArray(data.output)) {
    for (const item of data.output as Record<string, unknown>[]) {
      if (item.type === "message" && Array.isArray(item.content)) {
        for (const c of item.content as Record<string, unknown>[]) {
          if (c.type === "output_text" && typeof c.text === "string") text += c.text;
        }
      }
    }
  }
  return text;
}

async function openaiRequest(payload: Record<string, unknown>): Promise<Record<string, unknown>> {
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify(payload),
  });

  if (response.status === 429) {
    const retryAfter = response.headers.get("Retry-After");
    const detail = await response.text();
    console.error("OpenAI 429:", detail.slice(0, 400));
    throw { isRateLimit: true, retryAfterSeconds: retryAfter ? parseInt(retryAfter, 10) : 30, provider: "openai" };
  }
  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI API error: ${response.status} - ${errorText}`);
  }
  return await response.json();
}

/** Generate the full plan in one no-search call (fits the 150s time budget). */
async function generatePlan(systemPrompt: string): Promise<Record<string, unknown>> {
  const data = await openaiRequest({
    model: OPENAI_TEXT_MODEL,
    reasoning: { effort: "none" },
    input: [
      { role: "developer", content: systemPrompt },
      { role: "user", content: "Produce the full meal plan as JSON matching the schema. Do not search the web." },
    ],
    text: {
      format: { type: "json_schema", name: "weekly_meal_plan", strict: true, schema: MEAL_PLAN_SCHEMA },
    },
  });
  const text = extractOutputText(data);
  if (!text) throw new Error("No text in OpenAI response");
  return JSON.parse(text);
}

function validatePlan(plan: Record<string, unknown>, expectedMeals: number): void {
  const meals = plan.meals;
  if (!Array.isArray(meals) || meals.length === 0) {
    throw new Error("Meal plan validation failed: meals must be a non-empty array");
  }
  if (meals.length !== expectedMeals) {
    throw new Error(
      `Meal plan validation failed: expected ${expectedMeals} meals, got ${meals.length}`
    );
  }
  if (!Array.isArray(plan.grocery_list) || plan.grocery_list.length === 0) {
    throw new Error("Meal plan validation failed: grocery_list must be a non-empty array");
  }
}

// ─── Handler ────────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const requestStart = Date.now();
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Meal plans require an authenticated user (premium feature, multi-credit cost).
  const userToken = req.headers.get("x-user-token")
    || req.headers.get("Authorization")?.replace("Bearer ", "") || null;
  if (!userToken) {
    return Response.json({ error: "Missing authorization" }, { status: 401 });
  }
  const { data: { user }, error: authError } = await supabase.auth.getUser(userToken);
  if (authError || !user) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }
  const userId = user.id;

  // Rate limit (meal plans are heavy — keep this low).
  const { data: allowed } = await supabase.rpc("check_rate_limit", {
    p_user_id: userId,
    p_function_name: "generate-meal-plan",
    p_window_minutes: 1,
    p_max_requests: 10,
  });
  if (allowed === false) {
    return Response.json(
      { error: "rate_limited", message: "Too many requests. Please wait a moment." },
      { status: 429 }
    );
  }

  // Parse + validate input.
  let body: GenerateMealPlanRequest;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "Invalid request body" }, { status: 400 });
  }

  if (!body.daysCount || body.daysCount < 1 || body.daysCount > 7) {
    return Response.json({ error: "daysCount must be between 1 and 7" }, { status: 400 });
  }
  if (!Array.isArray(body.mealTypes) || body.mealTypes.length < 1 || body.mealTypes.length > 4) {
    return Response.json({ error: "mealTypes must contain 1-4 entries" }, { status: 400 });
  }
  if (!body.servings || body.servings < 1 || body.servings > 12) {
    return Response.json({ error: "servings must be between 1 and 12" }, { status: 400 });
  }

  const totalMeals = body.daysCount * body.mealTypes.length;
  if (totalMeals > MAX_MEALS) {
    return Response.json({ error: `Plan exceeds ${MAX_MEALS} meals` }, { status: 400 });
  }

  // Pre-check the balance (read-only). The actual deduction happens AFTER the
  // plan is generated, so a gateway timeout (504) never costs the user credits.
  const { data: balanceRow, error: balanceError } = await supabase
    .from("users")
    .select("purchased_credits, subscription_credits, rollover_credits")
    .eq("id", userId)
    .single();

  if (balanceError || !balanceRow) {
    console.error("balance check failed:", balanceError);
    return Response.json({ error: "Credit check failed" }, { status: 500 });
  }
  const available = (balanceRow.purchased_credits ?? 0)
    + (balanceRow.subscription_credits ?? 0)
    + (balanceRow.rollover_credits ?? 0);
  if (available < totalMeals) {
    return Response.json(
      {
        error: "insufficient_credits",
        message: `This plan costs ${totalMeals} credits.`,
        required: totalMeals,
        credits: {
          purchased_credits: balanceRow.purchased_credits ?? 0,
          subscription_credits: balanceRow.subscription_credits ?? 0,
          rollover_credits: balanceRow.rollover_credits ?? 0,
        },
      },
      { status: 402 }
    );
  }

  try {
    const aiStart = Date.now();
    const plan = await generatePlan(buildSystemPrompt(body));
    validatePlan(plan, totalMeals);
    console.log(`⏱ meal-plan AI: ${Date.now() - aiStart}ms, total: ${Date.now() - requestStart}ms`);

    // Charge now that we actually have a result to deliver.
    const { data: deductResult } = await supabase.rpc("deduct_credits", {
      p_user_id: userId,
      p_amount: totalMeals,
    });
    const credits = deductResult?.success
      ? {
          purchased_credits: deductResult.purchased_credits,
          subscription_credits: deductResult.subscription_credits,
          rollover_credits: deductResult.rollover_credits,
        }
      : undefined;

    const responseBody = JSON.stringify({ plan, creditsCharged: totalMeals, credits });
    if (responseBody.length > 4_000_000) {
      if (deductResult?.success) {
        try { await supabase.rpc("refund_credits", { p_user_id: userId, p_amount: totalMeals }); } catch (_) {}
      }
      return Response.json({ error: "Response exceeded size limit" }, { status: 502 });
    }
    return new Response(responseBody, { headers: { "Content-Type": "application/json" } });
  } catch (error: unknown) {
    // No credits were deducted (deduction happens only on success) — nothing to refund.
    if (error && typeof error === "object" && "isRateLimit" in error) {
      const rl = error as { retryAfterSeconds: number; provider: string };
      return Response.json(
        { error: "rate_limited", retryAfterSeconds: rl.retryAfterSeconds, provider: rl.provider },
        { status: 429 }
      );
    }
    console.error("generate-meal-plan error:", error);
    return Response.json(
      { error: "meal_plan_failed", message: "Meal plan generation failed. Please try again." },
      { status: 500 }
    );
  }
});
