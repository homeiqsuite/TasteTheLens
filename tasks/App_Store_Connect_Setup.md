# App Store Connect Setup Guide

## App Information

| Field | Value |
|-------|-------|
| **App Name** | Taste The Lens |
| **Subtitle** (30 char max) | Turn Photos Into Gourmet Food |
| **Bundle ID** | `com.eightgates.Taste-The-Lens` |
| **SKU** | `tastethelens-ios-v1` |
| **Primary Language** | English (U.S.) |
| **Primary Category** | Food & Drink |
| **Secondary Category** | Lifestyle |
| **Content Rights** | Does not contain third-party content that requires rights |
| **Age Rating** | 4+ |

---

## Version Information

| Field | Value |
|-------|-------|
| **Version** | 1.0.0 |
| **Build** | 1 |
| **Copyright** | 2026 Eight Gates LLC |
| **Minimum iOS** | iOS 16.2 |

---

## App Store Description

### Promotional Text (170 chars, updatable without new build)

```
Turn any photo into a gourmet recipe. Snap food, objects, or scenes — AI creates complete dishes with ingredients, steps, and photorealistic plating. Donate meals as you cook.
```

### Description (4000 char max)

```
Turn Any Photo Into a Gourmet Recipe

Taste The Lens is an AI-powered culinary engine that transforms visual inspiration into complete, restaurant-quality recipes. Photograph anything — food, landscapes, objects, or artwork — and watch as AI creates a gourmet dish inspired by what you see, complete with ingredients, step-by-step instructions, and photorealistic food photography.

A portion of every dollar we earn goes to fighting hunger. Every recipe you create helps feed someone in need.

WHAT YOU CAN DO

Capture Anything — Snap a photo of food, street art, a sunset, or your messy desk. The AI extracts colors, textures, and mood to build a dish concept.

Fusion Mode — Long-press the shutter to capture 2-3 images, then blend their visual DNA into a single, unique recipe.

Choose Your Chef — Pick from 5 distinct chef personalities, each with their own style, skill level, and culinary philosophy:
  - The Chef — Elevated home cooking from global cuisines
  - Dooby — Late-night comfort food and indulgent munchies
  - The Beginner — Max 5 ingredients, basic techniques only
  - Grizzly — Field-to-table cooking with game meats and open fire
  - Custom Chef — Build your own with preferred cuisines, skill level, and personality

Personalize Everything — Set dietary preferences (vegan, gluten-free, keto, halal, and 6 more) that automatically apply to every recipe. Exclude specific ingredients you dislike or can't eat.

Complete Recipe Details — Every recipe includes ingredients with substitutions, prep and cook times, nutrition info, sommelier pairings (wine, cocktail, and non-alcoholic), and a visual translation matrix showing how colors and textures became flavors.

Tasting Menus — Create themed multi-course dining experiences (amuse-bouche through dessert) and collaborate with friends via invite codes.

Challenges — Join timed community challenges, recreate dishes, submit photos, and compete with other cooks.

Save & Share — Build a personal recipe library backed up to the cloud. Export recipes as PDFs or shareable cards.

WHY PEOPLE LOVE IT

No cooking experience needed — The Beginner chef keeps things simple with basic techniques and everyday ingredients.

Advanced options too — Professional skill level with sophisticated techniques, specialty ingredients, and complex plating.

Never the same recipe twice — Every photo produces a completely unique dish. The same sunset photographed on two different days creates two different recipes.

Learn while you cook — Detailed instructions include practical tips, technique explanations, and budget-conscious substitutions.

PRICING

Free: 5 tastings per month, 1 chef personality, local saves

Credit Packs (one-time, never expire):
  Starter — 10 credits for $1.99
  Classic — 50 credits for $8.99
  Pantry — 90 credits for $14.99

Chef's Table — $9.99/month or $69.99/year
  75 credits/month, all chefs, custom chef builder, reimagination, cloud sync, clean exports, tasting menus, challenges

Atelier — $49.99/month
  500 credits/month, everything in Chef's Table plus bulk export

PRIVACY FIRST

Your photos are analyzed by AI to generate recipes and are never stored on our servers. Full control over your data with optional cloud sync and account deletion.

Privacy Policy: https://tastethelens.com/privacy
Terms of Service: https://tastethelens.com/terms
```

### Keywords (100 char max, comma-separated)

```
recipe AI,photo recipe,AI cooking,food photo,recipe generator,meal ideas,AI chef,gourmet,dietary
```

---

## URLs

| Field | URL |
|-------|-----|
| **Privacy Policy URL** | `https://tastethelens.com/privacy` |
| **Terms of Service URL** | `https://tastethelens.com/terms` |
| **Support URL** | `https://tastethelens.com/support` (needs to be created) |
| **Marketing URL** | `https://tastethelens.com` |

---

## App Review Information

### Review Notes

```
Taste The Lens uses the device camera to capture photos, which are sent to AI services (Google Gemini) via our server-side API to generate recipes. The app requires an internet connection for recipe generation.

Free tier: 5 recipe generations per month without an account.
Authenticated users: Sign in with email/password for cloud sync.

To test:
1. Open the app and grant camera access
2. Point the camera at any object (food, a book, a plant, etc.) and tap the shutter button
3. Wait ~15 seconds for the AI to generate a recipe
4. View the complete recipe with ingredients, instructions, and AI-generated food photography
5. Tap the heart to save the recipe locally

For Fusion Mode: long-press the shutter, capture 2-3 photos, then tap "Fuse"

No demo account is required for basic functionality (free tier works without sign-in).
```

### Contact Information

| Field | Value |
|-------|-------|
| **First Name** | Brandon |
| **Last Name** | Wade |
| **Email** | (your support email) |
| **Phone** | (your contact number) |

---

## Screenshots

### Required Sizes

| Device | Size (pixels) | Required |
|--------|--------------|----------|
| iPhone 16 Pro Max | 1320 x 2868 | Yes (6.9") |
| iPhone 16 Pro | 1206 x 2622 | Yes (6.3") |
| iPhone SE | 1242 x 2208 | Recommended (4.7") |

### Recommended Screenshots (6-10 per device)

**Screenshot 1 — Hero/Capture**
- Show: Camera viewfinder pointed at something interesting (sunset, street art, plate of food)
- Caption: **"Point. Snap. Taste."**
- Subtitle: "Turn any photo into a gourmet recipe"

**Screenshot 2 — Recipe Card**
- Show: Full recipe card with AI-generated dish photo, dish name, and color palette
- Caption: **"AI Creates Your Dish"**
- Subtitle: "Complete recipe with photorealistic plating"

**Screenshot 3 — Ingredients & Instructions**
- Show: Ingredients list with substitutions and step-by-step instructions
- Caption: **"Every Detail, Every Step"**
- Subtitle: "Ingredients, nutrition, prep time, and pairings"

**Screenshot 4 — Chef Selection**
- Show: Chef personality picker with The Chef, Dooby, Beginner, Grizzly, Custom
- Caption: **"Choose Your Chef"**
- Subtitle: "5 personalities or build your own"

**Screenshot 5 — Fusion Mode**
- Show: Camera with 2-3 thumbnails in the fusion tray at bottom
- Caption: **"Fusion Mode"**
- Subtitle: "Blend 2-3 photos into one recipe"

**Screenshot 6 — Dietary Preferences**
- Show: Dietary preference toggles (vegan, gluten-free, keto, etc.)
- Caption: **"Your Kitchen, Your Rules"**
- Subtitle: "10 dietary preferences built into every recipe"

**Screenshot 7 — Tasting Menus**
- Show: Multi-course tasting menu with course slots
- Caption: **"Host a Tasting Menu"**
- Subtitle: "Multi-course experiences with friends"

**Screenshot 8 — Saved Recipes**
- Show: Recipe library grid with saved dishes
- Caption: **"Your Recipe Collection"**
- Subtitle: "Save favorites and sync across devices"

### App Preview Video (optional but recommended)

- 15-30 seconds
- Flow: Camera capture → processing animation with color swatches → recipe reveal with hero image → scroll through ingredients/instructions → save
- No audio narration needed (use captions)

---

## In-App Purchases — Product Setup

### Subscription Group

**Group Name:** `Taste The Lens Subscriptions`
**Group ID:** Create in App Store Connect

All auto-renewable subscriptions must be in the same subscription group so users can upgrade/downgrade.

### Auto-Renewable Subscriptions

#### 1. Chef's Table (Monthly)

| Field | Value |
|-------|-------|
| **Reference Name** | Chef's Table Monthly |
| **Product ID** | `com.tastethelens.chefstable.monthly` |
| **Price** | $9.99 USD |
| **Duration** | 1 Month |
| **Subscription Group** | Taste The Lens Subscriptions |
| **Level** | 2 (below Atelier) |
| **Display Name** | Chef's Table |
| **Description** | 75 credits/month, all chefs, custom chef builder, reimagination, cloud sync, clean exports, tasting menus, and challenges. |

#### 2. Chef's Table (Annual)

| Field | Value |
|-------|-------|
| **Reference Name** | Chef's Table Annual |
| **Product ID** | `com.tastethelens.chefstable.annual` |
| **Price** | $69.99 USD |
| **Duration** | 1 Year |
| **Subscription Group** | Taste The Lens Subscriptions |
| **Level** | 2 (same level as monthly — Apple treats these as equivalent) |
| **Display Name** | Chef's Table (Annual) |
| **Description** | 75 credits/month, all chefs, custom chef builder, reimagination, cloud sync, clean exports, tasting menus, and challenges. Save 42% vs monthly. |

#### 3. Atelier (Monthly)

| Field | Value |
|-------|-------|
| **Reference Name** | Atelier Monthly |
| **Product ID** | `com.tastethelens.atelier.monthly` |
| **Price** | $49.99 USD |
| **Duration** | 1 Month |
| **Subscription Group** | Taste The Lens Subscriptions |
| **Level** | 1 (highest tier) |
| **Display Name** | Atelier |
| **Description** | 500 credits/month, everything in Chef's Table plus bulk export. For power users and creators. |

### Subscription Group Level Order

```
Level 1: Atelier ($49.99/mo)          ← highest
Level 2: Chef's Table ($9.99/mo or $69.99/yr) ← lower
```

Users upgrading from Chef's Table to Atelier get prorated credit. Users downgrading go to the lower tier at next renewal.

### Consumable In-App Purchases (Credit Packs)

#### 4. Starter Pack

| Field | Value |
|-------|-------|
| **Reference Name** | Starter Pack — 10 Credits |
| **Product ID** | `com.tastethelens.credits.starter` |
| **Type** | Consumable |
| **Price** | $1.99 USD |
| **Display Name** | Starter Pack |
| **Description** | 10 recipe credits. Credits never expire. |

#### 5. Classic Pack

| Field | Value |
|-------|-------|
| **Reference Name** | Classic Pack — 50 Credits |
| **Product ID** | `com.tastethelens.credits.classic` |
| **Type** | Consumable |
| **Price** | $8.99 USD |
| **Display Name** | Classic Pack |
| **Description** | 50 recipe credits. Unlocks clean exports (no watermark). Credits never expire. |

#### 6. Pantry Pack

| Field | Value |
|-------|-------|
| **Reference Name** | Pantry Pack — 90 Credits |
| **Product ID** | `com.tastethelens.credits.pantry` |
| **Type** | Consumable |
| **Price** | $14.99 USD |
| **Display Name** | Pantry Pack |
| **Description** | 90 recipe credits. Unlocks clean exports (no watermark). Credits never expire. |

### Legacy Products (Migration)

These exist for users who subscribed before the tier restructure. Do **not** remove them — they must remain so existing subscribers can manage/cancel.

| Product ID | Status |
|------------|--------|
| `com.tastethelens.pro.monthly` | Hidden from new users, available for existing subscribers |
| `com.tastethelens.pro.annual` | Hidden from new users, available for existing subscribers |

---

## Subscription Offer Details (required by Apple)

For each auto-renewable subscription, you must provide:

### Subscription Terms on Paywall

Apple requires clear subscription terms visible before purchase. The PaywallView already displays pricing and billing period. Ensure the following text is accessible on or near the paywall:

```
Payment will be charged to your Apple ID account at confirmation of purchase.
Subscription automatically renews unless canceled at least 24 hours before the
end of the current period. Your account will be charged for renewal within
24 hours prior to the end of the current period. You can manage and cancel
your subscriptions in your Apple ID account settings. Any unused portion of
a free trial period will be forfeited when purchasing a subscription.
```

---

## App Privacy (Data Collection)

Configure in App Store Connect under **App Privacy**:

### Data Collected

| Data Type | Usage | Linked to Identity | Tracking |
|-----------|-------|-------------------|----------|
| **Photos** | App Functionality | No | No |
| **Email Address** | App Functionality (auth) | Yes | No |
| **Name** | App Functionality (display name) | Yes | No |
| **User ID** | App Functionality | Yes | No |
| **Purchase History** | App Functionality | Yes | No |
| **Crash Data** | Analytics (if Crashlytics added) | No | No |

### Data NOT Collected

- Location
- Contacts
- Browsing History
- Search History
- Diagnostics (unless Crashlytics is added)
- Advertising Data
- Financial Info (Apple handles payments)

---

## Age Rating Questionnaire

Answer these in App Store Connect:

| Question | Answer |
|----------|--------|
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Prolonged Graphic or Sadistic Violence | None |
| Profanity or Crude Humor | None |
| Mature/Suggestive Themes | None |
| Horror/Fear Themes | None |
| Medical/Treatment Info | None |
| Alcohol, Tobacco, Drug Use/References | Infrequent/Mild (sommelier wine pairings) |
| Simulated Gambling | None |
| Sexual Content or Nudity | None |
| Unrestricted Web Access | No |
| Contests | No |

**Result:** Likely **4+** (wine pairing references are informational, not promotional)

---

## Pre-Submission Checklist

### App Store Connect Configuration
- [ ] Create app record with bundle ID `com.eightgates.Taste-The-Lens`
- [ ] Set app name, subtitle, and category
- [ ] Upload app icon (1024x1024, no transparency, no rounded corners)
- [ ] Enter description, keywords, promotional text
- [ ] Set privacy policy URL and support URL
- [ ] Complete App Privacy questionnaire
- [ ] Complete Age Rating questionnaire
- [ ] Add review notes and contact info

### Products
- [ ] Create subscription group "Taste The Lens Subscriptions"
- [ ] Add Chef's Table Monthly (`com.tastethelens.chefstable.monthly`) at $9.99
- [ ] Add Chef's Table Annual (`com.tastethelens.chefstable.annual`) at $69.99
- [ ] Add Atelier Monthly (`com.tastethelens.atelier.monthly`) at $49.99
- [ ] Set subscription levels (Atelier = 1, Chef's Table = 2)
- [ ] Add Starter Pack consumable (`com.tastethelens.credits.starter`) at $1.99
- [ ] Add Classic Pack consumable (`com.tastethelens.credits.classic`) at $8.99
- [ ] Add Pantry Pack consumable (`com.tastethelens.credits.pantry`) at $14.99
- [ ] Submit products for review (required before app review)
- [ ] Hide legacy product IDs from new users

### Screenshots & Media
- [ ] Capture screenshots on iPhone 16 Pro Max (1320 x 2868)
- [ ] Capture screenshots on iPhone 16 Pro (1206 x 2622)
- [ ] Upload 6-10 screenshots per device size
- [ ] Record app preview video (optional, 15-30s)

### Agreements
- [ ] Accept Paid Applications agreement in App Store Connect
- [ ] Set up banking and tax information
- [ ] Verify paid apps contract is active (required for IAPs)

### Build
- [ ] Archive with Production build config (ensures `aps-environment = production`)
- [ ] Verify `PRODUCTION` build flag is set (debug menu hidden, logging disabled)
- [ ] Upload build via Xcode or Transporter
- [ ] Wait for build processing (~15-30 min)
- [ ] Select build for submission

### Testing
- [ ] Test all IAPs in Sandbox environment
- [ ] Test subscription upgrade/downgrade flow
- [ ] Test restore purchases
- [ ] Test credit pack consumption
- [ ] Verify receipt validation works
- [ ] Test on TestFlight with external testers before submission
