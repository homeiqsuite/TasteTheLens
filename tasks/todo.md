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
