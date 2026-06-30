# App Privacy Label — Answer Key (Taste The Lens)

A copy-paste guide for filling out Apple's **App Privacy** questionnaire in App Store Connect.

- **App:** Taste The Lens
- **Bundle ID:** `com.eightgates.Taste-The-Lens`
- **Source:** Engineering data-flow audit (see caveat at the bottom — this is not legal advice)

---

## 1. Where to fill this out

1. Sign in to **App Store Connect** → **My Apps** → **Taste The Lens**.
2. In the left sidebar (under the **General** group), open **App Privacy**.
3. Click **Edit** next to **Data Types**.
4. Answer "Do you or your third-party partners collect data from this app?" → **Yes** (we collect account, content, and usage data).
5. For each data type below, check the box, then on the next screens select:
   - **How is this data used?** → choose the listed purpose(s).
   - **Is this data linked to the user's identity?** → **Yes** for everything we collect (the app has accounts; data is tied to a Supabase user UUID).
   - **Is this data used for tracking purposes?** → **No** for everything (see the Tracking section).

### Key stance (memorize this)

> **Data is collected and linked to the user. NONE of it is used for Tracking** — there is no IDFA, no cross-app/cross-website tracking, and no sharing of data with data brokers or advertising networks.

Apple's three questions per data type, and our standing answers:

| Apple question | Our answer |
|---|---|
| Is this data **collected**? | Yes (for the types listed in §2) |
| Is it **linked** to the user's identity? | **Yes** (account-based app) |
| Is it used for **tracking**? | **No** (always) |

---

## 2. Data types — what to declare

For each row: in App Store Connect, select the **Apple data category**, then on the follow-up screens mark **Linked = Yes**, **Tracking = No**, and pick the listed **Purpose**.

| Apple data category | Collected? | Linked to user? | Used for tracking? | Purpose(s) |
|---|---|---|---|---|
| **Contact Info → Email Address** (account email) | Yes | Yes | No | App Functionality |
| **Contact Info → Name** (display name) | Yes | Yes | No | App Functionality |
| **User Content → Photos or Videos** (captured/picked inspiration photos sent for recipe analysis) | Yes | Yes (when signed in) | No | App Functionality |
| **User Content → Other User Content** (generated recipes, meal plans, dietary preferences/restrictions, custom chef config, challenge submissions, share-link content) | Yes | Yes | No | App Functionality |
| **Identifiers → User ID** (Supabase account UUID) | Yes | Yes | No | App Functionality |
| **Identifiers → Device ID** (APNs / Firebase Cloud Messaging push token) | Yes | Yes | No | App Functionality (push notifications) |
| **Purchases → Purchase History** (IAP credit packs / subscription tier) | Yes | Yes | No | App Functionality |
| **Usage Data → Product Interaction** (recipe-generation events: capture mode, image provider, token counts, estimated cost) | Yes | Yes | No | Analytics (first-party) and App Functionality |

> Tip: when a single data type serves more than one purpose (e.g., Product Interaction), check **both** purposes on the "How is this data used?" screen.

### Note on dietary restrictions / preferences (the Health nuance)

It is tempting to file dietary restrictions, allergies, or preferences under **Health & Fitness → Health**. **Do not.** Declare them under **User Content → Other User Content** instead.

- Apple's **Health** category is intended for data from **HealthKit** and clinical/fitness health records. **Taste The Lens does not use HealthKit** and does not collect medical/health records.
- Dietary preferences here are free-form recipe-personalization inputs the user types (e.g., "low FODMAP," "GERD-friendly," "plant-based") — they behave like other user-authored content, not measured health metrics.
- Filing them as **Health** would over-declare and imply HealthKit/medical handling we don't perform. **Other User Content** is the accurate, defensible choice.

If your dietary fields ever capture explicit medical-condition data tied to a diagnosis, revisit this with legal counsel — but as built, **Other User Content** is correct.

### Diagnostics — likely NOT collected

- We ship **no crash-reporting / diagnostics SDK** (no Crashlytics, no Sentry, etc.).
- Therefore **Diagnostics → Crash Data / Performance Data / Other Diagnostic Data = Not Collected.**
- ⚠️ If you later add a crash/diagnostics SDK, you must come back and declare **Diagnostics**.

### Explicitly NOT collected — leave these unchecked

| Apple data category | Status | Why |
|---|---|---|
| **Location** (Precise or Coarse) | Not Collected | No location APIs, no geofencing. |
| **Contacts** | Not Collected | No address-book access. |
| **Browsing History** | Not Collected | App is not a browser. |
| **Search History** | Not Collected | We don't log app search queries as a tracked data type. |
| **Sensitive Info** (Apple's category) | Not Collected | No racial/ethnic, religious, sexual-orientation, biometric, etc. data. (Dietary prefs → see Health nuance above.) |
| **Financial Info** | Not Collected | Apple processes IAP; we only receive a **signed StoreKit receipt / transaction**, not card or bank data. |
| **Advertising Data / IDFA** | Not Collected | No ads, no IDFA, no ATT prompt. |
| **Health & Fitness → Health / Fitness** | Not Collected | No HealthKit; dietary prefs filed as User Content. |
| **Diagnostics** | Not Collected | No crash/diagnostics SDK. |

---

## 3. Third parties data is shared with / processed by

These are **service providers / data processors** that handle data **on our behalf** to deliver app functionality. **None are data brokers, and none receive data for advertising or their own marketing.**

| Party | Role | What they process |
|---|---|---|
| **Supabase** | Backend / processor (database, auth, storage, edge functions, first-party analytics) | Account, content, usage metadata |
| **Google — Gemini** | AI processor (recipe analysis) | Inspiration photos + recipe parameters |
| **Google — Imagen** | AI processor (food image generation) | Generated text prompts |
| **Google — Firebase Cloud Messaging** | Push delivery | APNs/FCM device token (Firebase **Analytics is disabled**) |
| **Fal.ai — Flux** | AI processor (food image generation) | Generated text prompts |
| **Apple** | Sign in with Apple, StoreKit (IAP), APNs (push) | Auth, purchase transaction, push token |

Notes for App Store Connect:
- Apple's questionnaire asks **per data type** whether **"third-party partners"** collect it — answer **Yes** where these processors are involved, but keep **Tracking = No**.
- Auth tokens are stored client-side in the iOS **Keychain**; they are not a separately declarable Apple data type but are noted here for completeness.

---

## 4. Tracking

**Does this app track? → NO.**

On the **"Is this data used for tracking purposes?"** screen, select **No** for every data type. Reasons:

- **No IDFA** and **no App Tracking Transparency (ATT) prompt** — we never request the advertising identifier.
- **No cross-app or cross-website tracking** — we do not link this app's data with data collected from other companies' apps or sites for advertising/measurement.
- **No data brokers** — we do not sell or share data with data brokers.
- **No ad networks / advertising SDKs** — the app shows no ads and embeds no ad SDKs.
- **No third-party analytics SDKs** — analytics are **first-party (Supabase)** and contain **usage/cost metadata only**; Firebase Analytics is **disabled**.

Because none of the above applies, the app's Privacy "Nutrition Label" should show **"Data Not Used to Track You"** alongside the **"Data Linked to You"** section.

---

## 5. Required URLs / settings checklist

- [ ] **Privacy Policy URL** is set (App Store Connect → App Privacy → Privacy Policy): `https://tastethelens.com/privacy`
- [ ] **Account deletion is available in-app** — Apple requires that apps offering account creation also offer in-app account deletion. ✅ Confirmed present in-app. (If Apple's submission flow asks, point to the in-app deletion path.)
- [ ] **Age rating** — set a **13+ minimum** to match the Terms of Service (no users under 13).
- [ ] After saving Data Types, click **Publish** so the label goes live with the next submission.

---

## 6. Caveat

This document is an **engineering-prepared mapping** of the app's actual data flows to Apple's privacy categories. **It is not legal advice.** Apple updates the App Privacy categories and questions periodically — **confirm each selection against the current App Store Connect wording at submission time**, and have counsel review if you handle anything that could be construed as sensitive or health data.
