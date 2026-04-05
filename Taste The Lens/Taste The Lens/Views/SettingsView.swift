import SwiftUI
import SwiftData
import os

private let logger = makeLogger(category: "Settings")

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteAccountConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showSignIn = false
    @State private var showProfile = false
    @State private var showPaywall = false
    @State private var exportFileURL: URL?
    @State private var showExportShare = false
    @State private var isExporting = false

    private let authManager = AuthManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Account
                    settingsSection("Account") {
                        VStack(spacing: 0) {
                            accountRow
                            if authManager.isAuthenticated {
                                settingsDivider
                                settingsButton("Sign Out", icon: "rectangle.portrait.and.arrow.right", color: .red) {
                                    showSignOutConfirmation = true
                                }
                            }
                        }
                    }

                    // Cooking Style
                    cookingStyleSection

                    // Preferences
                    settingsSection("Preferences") {
                        NavigationLink {
                            PreferencesView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.textPrimary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Dietary & Cooking Preferences")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Experience level, dietary restrictions")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textQuaternary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                    }

                    // Credits (featured)
                    creditsFeaturedSection

                    // Notifications
                    if authManager.isAuthenticated {
                        settingsSection("Notifications") {
                            NavigationLink {
                                NotificationSettingsView()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bell")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Theme.textPrimary)
                                        .frame(width: 24)
                                    Text("Push Notifications")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textQuaternary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 13)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // App
                    settingsSection("App") {
                        VStack(spacing: 0) {
                            settingsButton("Export My Data", icon: "square.and.arrow.up", color: Theme.textPrimary) {
                                exportData()
                            }
                            settingsLink("Privacy Policy", icon: "hand.raised", url: "https://tastethelens.com/privacy")
                            settingsLink("Terms of Service", icon: "doc.text", url: "https://tastethelens.com/terms")
                        }
                    }

                    // Version
                    Text("Taste The Lens v\(appVersion)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textQuaternary)
                        .padding(.top, 4)

                    Spacer().frame(height: 40)
                }
                .padding(.top, 20)
            }
            .refreshable {
                await refreshSettings()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                }
            }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    Task { await authManager.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll stay signed in on other devices. Your local recipes will remain on this device.")
            }
            .sheet(isPresented: $showSignIn) {
                SignInView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: .topUp)
            }
            .sheet(isPresented: $showExportShare) {
                if let url = exportFileURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    // MARK: - Account

    @ViewBuilder
    private var accountRow: some View {
        if authManager.isAuthenticated {
            Button { showProfile = true } label: {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Theme.primary.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Text(String(authManager.displayName.prefix(1)).uppercased())
                                .font(.system(size: 18, weight: .bold, design: .serif))
                                .foregroundStyle(Theme.primary)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(authManager.displayName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.textPrimary)
                        Text(authManager.displayEmail)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textQuaternary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 12) {
                Circle()
                    .fill(Theme.divider)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.textTertiary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Guest Mode")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Sign in to sync recipes across devices")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer()

                Button { showSignIn = true } label: {
                    Text("Sign In")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .stroke(Theme.primary, lineWidth: 1)
                        )
                }
            }
            .padding(14)
        }
    }

    // MARK: - Cooking Style Section

    private var cookingStyleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cooking Style")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.horizontal, 16)

            ChefSelectionView(showHeader: false)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Credits Featured Section

    private var creditsFeaturedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Credits")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    // Top row: icon + text
                    HStack(spacing: 14) {
                        // Icon tile
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.gold.opacity(0.20))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Image(systemName: "circle.grid.3x3.fill")
                                    .font(.system(size: 19))
                                    .foregroundStyle(Theme.primary)
                            }

                        // Text block
                        VStack(alignment: .leading, spacing: 3) {
                            (Text("\(UsageTracker.shared.remainingGenerations) credits")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Theme.primary)
                            + Text(" remaining")
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textPrimary))

                            Text("Keep creating delicious recipes")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        Spacer(minLength: 0)
                    }

                    // Bottom row: recipes-left + CTA button
                    HStack {
                        HStack(spacing: 3) {
                            Text("✦")
                                .font(.system(size: 9))
                                .foregroundStyle(Theme.gold)
                            Text("= \(UsageTracker.shared.remainingGenerations) recipes left")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textTertiary)
                        }

                        Spacer()

                        // CTA button
                        Button { showPaywall = true } label: {
                            HStack(spacing: 5) {
                                Text("Buy More Credits")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Theme.primary))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)

                // Legacy subscription (conditional)
                if StoreManager.shared.hasActiveLegacySubscription {
                    Divider()
                        .background(Theme.gold.opacity(0.2))
                    Button {
                        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "creditcard")
                                .font(.system(size: 13))
                            Text("Manage Legacy Subscription")
                                .font(.system(size: 13))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: [
                            Theme.warmCardBg,
                            Color(red: 0.988, green: 0.949, blue: 0.871), // warm golden cream
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Theme.gold.opacity(0.30), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Helpers

    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.horizontal, 16)

            content()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Theme.cardSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
        }
    }

    private func settingsButton(_ title: String, icon: String, color: Color = Theme.textPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(color)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private func settingsLink(_ title: String, icon: String, url: String) -> some View {
        Button {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textQuaternary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private var settingsDivider: some View {
        Divider()
            .background(Theme.divider)
            .padding(.leading, 50)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func refreshSettings() async {
        async let creditsTask: () = UsageTracker.shared.syncCreditsFromServer()
        async let usageTask: () = UsageTracker.shared.syncUsageFromServer()
        _ = await (creditsTask, usageTask)
        logger.info("Settings refreshed")
    }

    private func exportData() {
        logger.info("Exporting user data")
        let descriptor = FetchDescriptor<Recipe>()
        let recipes = (try? modelContext.fetch(descriptor)) ?? []

        let userInfo = DataExporter.UserExportInfo(
            displayName: authManager.displayName,
            email: authManager.email,
            memberSince: authManager.memberSinceDate,
            subscriptionTier: EntitlementManager.shared.hasEverPurchased ? "Credits" : "Free"
        )

        let jsonData = DataExporter.exportJSON(recipes: recipes, user: userInfo)
        if let url = DataExporter.exportFileURL(data: jsonData) {
            exportFileURL = url
            showExportShare = true
            logger.info("Data export ready — \(recipes.count) recipes")
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
