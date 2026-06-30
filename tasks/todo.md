# Security Hardening + Legal Protection — 2026-06-30 (current)

Security/privacy audit found the app was NOT fully secured. Fixes below close cross-user data
exposure, unauthenticated paid-API abuse, push/temp-file issues, and move the operating entity to
HomeIQ Suite, Inc. (Delaware). iOS `xcodebuild` BUILD SUCCEEDED.

## Backend (Supabase) — migration files written; DEPLOY GATED on explicit approval
- [x] `20260630010000_baseline_recovered_schema.sql` — recover untracked security controls
      (rate_limits, check_rate_limit, deduct_credit, refund_credit) into VCS + missing
      `SET search_path` hardening + explicit service_role grants; new `check_ip_rate_limit`.
- [x] `20260630020000_secure_sharing.sql` — FIX C1: drop blanket "anyone can read non-deleted"
      SELECT on meal_plans/meal_plan_meals/recipes; add per-item `share_token`; reads only via
      SECURITY DEFINER get_shared_* (token arg, not enumerable); owner-only share_/unshare_;
      tighten dish/inspiration storage policies to token-shared; lock meal-images bucket
      private (owner + token-shared reads) so unshare/delete actually revokes access.
- [x] BRANCH-VALIDATED on a throwaway Supabase branch: before→non-owner saw 2 plans/2 recipes
      (leak); after→non-owner sees 0/0, owner still sees own, get_shared_*(correct token)=1 /
      (wrong token)=0. Independent /security-review: no high-confidence vulns introduced.
- [x] Edge functions: guest IP rate limiting (generate-image/analyze-image/screen-image — H1),
      image count/size caps, prompt-length cap, generic errors (no String(error) leak),
      Gemini key moved from URL query → x-goog-api-key header.
- [ ] DEPLOY (gated): db push both migrations + redeploy 3 edge functions on a BRANCH first;
      run get_advisors; then prod. Confirm verify_jwt + bucket privacy in dashboard.

## iOS (BUILD SUCCEEDED)
- [x] Share-token plumbing: DeepLinkHandler token links; SyncManager fetch via get_shared_* RPCs +
      shareLinkFor* minting via share_* RPCs; routing/AppSheet/DeepLinked*View updated.
- [x] H3: push deep_link routed through DeepLinkHandler.parse (no arbitrary URL open).
- [x] H4: TempFileManager (complete file protection + backup-excluded + cleanup-after-share) used by
      SharePresenter/DataExporter/PublishedMenuView.
- [x] L1: redacted email / dietary / full-deep-link-URL logs.
- [x] In-app: strengthened pre-generation notice (health/allergen/medical), recipe completion
      disclaimer, Terms/Privacy acceptance line on Sign-In.

## Legal / docs
- [x] privacy.html + terms.html: Eight Gates LLC → HomeIQ Suite, Inc.; Texas LLC → Delaware corp;
      Travis County/Texas governing law+arbitration → Delaware; dates → June 30, 2026.
- [x] privacy.html: new §5.5 Recipe & Meal Plan Sharing disclosure.
- [x] `tasks/app-privacy-label.md` — Apple App Privacy questionnaire answer key.

## Remaining (user/owner)
- [ ] Approve + run the gated backend deploy; on-device test share round-trip with a 2nd account.
- [ ] App Store Connect: fill privacy label from app-privacy-label.md; confirm privacy-policy URL.
- [ ] NOTE: old share links (raw recipe id) stop resolving under the token model — low impact pre-launch.

---

# Guest free-tier server-side enforcement — 2026-06-30

## Problem
- The 5/month guest limit lived ONLY in the client (`UsageTracker` UserDefaults). `analyze-image`
  did NO enforcement for guests — clearing app data or calling the endpoint directly granted
  unlimited free AI generations (~$0.045 cost each, $0 revenue). The only true profit leak found
  in the pricing analysis.

## Done (approach: stable Keychain guest id — chosen over anonymous-auth / App Attest)
- [x] Migration `20260630000000_guest_usage.sql` (APPLIED to marimaxtqnzmsynsvhrc): `guest_usage`
      table + `deduct_guest_generation`/`refund_guest_generation` RPCs mirroring deduct_credit's
      free-tier branch (monthly reset, cap, refund). RLS on, granted to service role only.
      Verified: deduct caps at limit → 402; refund decrements.
- [x] `analyze-image` (deployed): reads `x-guest-id`, validates UUID; guest branch runs screening
      + deduct in parallel, 402 over limit, refunds on screening/AI failure. Old clients (no header)
      keep the screening-only path — backward compatible.
- [x] iOS: `Store/GuestIdentity.swift` (Keychain UUID); `invokeEdgeFunction` sends `x-guest-id`
      for guests; local `incrementGuestUsage()` now only a fallback when server returns no balance.

## Follow-ups (optional, out of scope for the leak fix)
- [ ] Guest count sync on launch (today a guest who cleared data shows "5 free" locally but the
      server rejects with 402 → paywall; correct enforcement, slightly confusing UI until reconcile).
- [ ] App Attest to defeat reinstall-farming + direct API calls (stronger anti-abuse).

---

# Meal-plan de-dup + delete

## Findings
- Photo recipes: `DishHistory` (per-chef, UserDefaults, 20/chef, 30-day decay) → analyze-image
  hardExcluding/softAvoiding. Recipes already have swipe-delete (SyncManager.deleteRecipeRemotely).
- Meal plans had NEITHER de-dup nor delete.

## Done
- [x] De-dup: `MealPlanPipeline.recentLibraryDishNames` (distinct dish names from saved non-deleted
      plans, newest-first, cap 50) → `excludeDishes` in the request → generate-meal-plan injects an
      "AVOID REPEATS" constraint (slice 80). Scales with the library; deleting plans frees names.
- [x] Delete: `SyncManager.deleteMealPlanRemotely` (server soft-delete + local cascade);
      MealPlanView toolbar "Delete plan" (confirm + dismiss); SavedMealPlansView context-menu delete.
- [x] Redeployed generate-meal-plan v7; xcodebuild BUILD SUCCEEDED.

---

# Meal plan export, deep-link sharing & Saved hub

## Done
- [x] Models: `isFavorite` on MealPlan + PlannedMeal; `remoteId` on PlannedMeal (local-only favorites)
- [x] Migration `20260628000000_meal_plan_sharing.sql` (applied): public-read SELECT on
      meal_plans/meal_plan_meals + public `meal-images` bucket + owner write policies — verified
- [x] Sync: `SupabaseMealPlanDTO`, `SupabaseMealDTO` (+`PlannedMealContent`);
      `SyncManager.syncMealPlan/fetchMealPlan/fetchMeal` mirroring recipe sync (images → meal-images)
- [x] Deep links: `DeepLinkHandler` mealplan/meal hosts + url(for:); `AppSheet` + onOpenURL;
      `DeepLinkedMealPlanView`/`DeepLinkedMealView` (local-first, else server fetch)
- [x] PDF: `PDFExporter.generateMealPDF` + `generateMealPlanPDF` (cover + grocery list + per-meal)
- [x] UI: `SharePresenter` helper; favorite heart + share menu (Export PDF / Share link) in
      MealDetailView & MealPlanView (sync-on-share); `SavedMealPlansView` → segmented hub
      (Plans · Favorites · Shared)
- [x] xcodebuild BUILD SUCCEEDED

## Needs on-device verification (auth + a generated plan required; can't run headlessly)
- [ ] PDF: export a meal & a plan → images embed, grocery list renders, share sheet attaches
- [ ] Deep-link round-trip: Share plan/meal link → row in meal_plans/meal_plan_meals + image in
      meal-images → tap tastethelens://mealplan|meal/{id} opens it (try a 2nd account for public read)
- [ ] Favorites/hub: heart a meal & a plan → appear under Favorites; shared plans under Shared

---

# Two more chefs + selective images

## Chefs: The Gut Guide (Low-FODMAP) + The Alkalist (Alkaline)
- [x] `ChefPersonality` cases `lowfodmap`/`alkaline` + all arms; `ChefTheme` periwinkle/cyan
- [x] Prompts added to `analyze-image` (source — ships with iOS release) and
      `generate-meal-plan` personas (deployed v6)
- [x] Hero avatars generated (GPT Image 1, transparent) + installed:
      chef-lowfodmap (stethoscope, gut-friendly props), chef-alkaline (green juice/salad)
- [x] Temp `generate-chef-avatar` neutralized again (410)

## Selective meal images (don't pay for the whole bundle)
- [x] `MealPlanPipeline.generateImages(for: [PlannedMeal])` — runs the progressive
      queue on any subset; `generateAllImages` delegates to it
- [x] `MealPlanView` selection mode: "Add images" → tap the recipes you want (or All) →
      bottom bar "Generate N · N credits" → only those generate; per-meal single-tap kept;
      backgroundable + resumes the selected set on foreground
- [x] xcodebuild BUILD SUCCEEDED

---

# Meal Plan — crash fix + progressive images

## Bug: "no such table: ZMEALPLAN" / store corruption
Root cause: TWO SwiftData `ModelContainer`s opened the same `default.store` with
different schemas — the main `.modelContainer(for: [Recipe, MealPlan])` modifier AND a
second `ModelContainer(for: Recipe.self)` at Taste_The_LensApp.swift:34 (Recipe-only).
The Recipe-only container created/raced the store without the MealPlan tables →
"no such table", plus "busy prepared statement"/"I/O error" from concurrent access.
- [x] New `Config/AppModelContainer.swift` — single shared container (`[Recipe, MealPlan]`)
      with a safe rebuild fallback if the on-disk store is unopenable
- [x] App uses `.modelContainer(AppModelContainer.shared)` and the same container's
      context for background sync (no more ad-hoc container)
- [x] Self-heals on next launch: additive migration adds the tables, or fallback rebuilds.
      No reinstall required.

## Feature: progressive, backgroundable meal images
- [x] `MealPlanPipeline.generateAllImages` — sequential queue, saves each image as it
      lands (live UI reveal), stops on no-credits/cancel, resumable (skips done meals)
- [x] `beginBackgroundTask` assertions around plan generation AND the image queue so
      backgrounding doesn't instantly kill an in-flight request
- [x] `MealPlanView` — "Generate all N images" card with live progress bar + Stop;
      per-meal Creating…/Queued states; auto-resumes the queue on return to foreground
- [x] xcodebuild BUILD SUCCEEDED
- Note: iOS only grants finite background time (~30s), so a full 21-image run won't
  always complete purely in the background — but every finished image is persisted and
  the queue resumes on foreground, so the user can keep checking back.

---

# Weekly Meal Plans + 3 New Chefs

Feature: each chef generates a researched weekly meal plan (configurable meals/day) with a
consolidated grocery list, per-meal cooking steps, and optional per-meal images. Adds 3 chefs:
The Nutritionist (healthy), The Healer (GERD/LPR), The Botanist (plant-based).
Backend uses OpenAI GPT-5.4 for text + GPT Image 2 (medium) for images.
NOTE: the shipped generate-meal-plan makes ONE no-search call with `reasoning: { effort: "none" }`
("Do not search the web") to fit the 150s edge wall-clock — research notes come from the model's
built-in knowledge, NOT live web search. Cost figures below were corrected accordingly (2026-06-30).

## Done
- [x] 3 chefs added to `ChefPersonality.swift` (+ themes in `ChefTheme.swift`); auto-gated premium
- [x] New chefs' prompts mirrored into `analyze-image` so the photo flow works for them too
- [x] Backend: `generate-meal-plan` edge function (GPT-5.4, single no-search call, strict JSON schema)
- [x] Backend: `generate-image` extended with `gptimage2` provider + optional `chargeCredit`
- [x] Migration `20260626000000_meal_plans.sql`: tables + `deduct_credits`/`refund_credits` RPCs
- [x] iOS: `Models/MealPlan.swift` (MealPlan/PlannedMeal/GroceryItem) + container registration
- [x] iOS: `Services/MealPlanPipeline.swift`; `gptImage2` registered in `ImageGenerationProvider`
- [x] iOS views: Setup (credit preview), Plan overview, Meal detail, Grocery list, Saved plans
- [x] Dashboard entry point ("Weekly Meal Plan" card)
- [x] `xcodebuild` — BUILD SUCCEEDED, no errors

## Cost (per 21-meal week, 3 meals/day) — CORRECTED 2026-06-30
- Text plan: ONE no-search GPT-5.4 call (effort:none) → est. ~$0.10–0.15, NOT the old
  ~$0.53 "+web search" figure (web search is disabled in the shipped code).
- Images are opt-in, charged separately at 1 credit each (~$0.053 GPT Image 2). A full
  21-image bundle ≈ $1.11 cost — but only if the user requests every image.
- User pays: 21 credits (text plan, deducted after generation) + up to 21 credits (images,
  opt-in) = up to 42 credits/week.
- Profitability: text plan is HIGHLY profitable (21 credits ≈ $1.96 net at Feast/30% vs ~$0.12
  cost). The earlier "runs at a loss" framing was based on the stale web-search cost — no longer true.

## Deployed to live project (marimaxtqnzmsynsvhrc)
- [x] Migration `20260626000000_meal_plans.sql` applied (2 tables, 2 RPCs, 2 policies; legacy RPCs intact)
- [x] Hardened new RPCs with `SET search_path = public`
- [x] Deployed `generate-image` v7 (gptimage2 + chargeCredit; verify_jwt=false preserved)
- [x] Deployed `generate-meal-plan` v1 (verify_jwt=false; self-auths via x-user-token)

## Remaining (blocked on key / iOS release)
- [ ] **Add `OPENAI_API_KEY` to Supabase secrets** (dashboard → Edge Functions → Secrets, or
      `supabase secrets set OPENAI_API_KEY=… --project-ref marimaxtqnzmsynsvhrc`).
      Until set, `generate-meal-plan` and the `gptimage2` provider fail (credits auto-refund).
      Existing Imagen/Flux image generation is unaffected.
- [ ] Confirm OpenAI model id `gpt-5.4` (constant in generate-meal-plan/index.ts) for the account
- [ ] Deploy `analyze-image` (additive new-chef prompts) — ship WITH the next iOS build, not before
- [ ] After key is set: invoke per chef (days=7, meals=3) → verify 21 meals, grocery list,
      sources populated, GERD zero-triggers, plant-based 100% vegan, healthy nutrition each meal
- [ ] Verify image gen cost ≈ $0.053 and credit deduct(21)/refund + per-image charge

---

# Bug fixes — recipe step nav + onboarding skip (current)

## Bug 1 — "Next Step" stays on same screen (RecipeCardView)
Root cause: the redesign placed the paged `TabView(selection: $currentStep).page` under an
`.ignoresSafeArea(.container, edges: [.top, .bottom])` ancestor (Layer 2). A paged TabView under an
ignoresSafeArea ancestor stops honoring programmatic `selection` changes, so FloatingActionBar's
"Next Step" updates `currentStep` but the page doesn't move. Old (working) code kept the TabView
free of any ignoresSafeArea ancestor.
- [x] Remove `.ignoresSafeArea` from the TabView's ancestor (Layer 2 VStack)
- [x] Keep the card's bottom bleed via the background shape's own `.ignoresSafeArea(.bottom)`
- [x] Preserve top alignment by subtracting `proxy.safeAreaInsets.top` from the hero spacer
- [ ] Runtime verify: "Let's Cook"/"Next Step"/"Previous" advance pages (recipe card is behind the capture→AI flow)

## Bug 2 — onboarding skipped after reinstall (auth)
Root cause: Supabase session persists in the iOS Keychain across uninstall; `restoreSession()` at launch
re-authenticates silently, and OnboardingView dismissed onboarding on ANY `isAuthenticated` flip.
- [x] Only dismiss onboarding on an INTERACTIVE sign-in (`didStartInteractiveSignIn` flag)
- [ ] (Optional follow-up) Clear a stale Keychain session on first launch after a fresh install
- [ ] Runtime verify: reinstall → onboarding shows → Next advances through all 3 pages

## Verification
- [x] `xcodebuild` compile check
- [ ] On-device tap test for both flows

---

# Pricing Model Implementation — 6 Issues

## Issue 1: Pantry Pack Credit Adjustment
- [x] Reduce Pantry credits from 100 to 90 in `StoreManager.creditPackAmounts`
- [ ] Note: Price change to $16.99 requires App Store Connect update

## Issue 2: Atelier Price Documentation
- [x] Add comment noting planned $69.99 price change (App Store Connect)

## Issue 3: Credit-to-Subscription Upgrade Nudge
- [ ] Add purchase count + spend tracking to `UsageTracker`
- [ ] Track purchases in `StoreManager.purchase()`
- [ ] Add nudge check + sheet state to `PaywallView`
- [ ] Create `SubscriptionNudgeSheet` UI

## Issue 4: Annual Subscription Option
- [ ] Add `chefsTableAnnualId` product ID to `StoreManager`
- [ ] Add `chefsTableAnnualProduct` accessor
- [ ] Update tier mapping for annual ID
- [ ] Add monthly/annual toggle to `PaywallView` subscription section
- [ ] Update subscription card to show billing note for annual

## Issue 5: Remove Watermark for Classic+ Credit Buyers
- [ ] Add `hasPurchasedClassicOrHigher` flag to `UsageTracker`
- [ ] Set flag on Classic/Pantry purchase in `StoreManager`
- [ ] Split `.cleanExport` case in `EntitlementManager.hasAccess()`

## Issue 6: Credit Expiry Notifications
- [ ] Create `CreditExpiryNotificationService.swift`
- [ ] Expose reset date from `UsageTracker`
- [ ] Schedule notification after credit refresh
- [ ] Cancel notification on subscription lapse
- [ ] Schedule on app launch
