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
