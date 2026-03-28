import SwiftUI
import SwiftData
import os

private let logger = makeLogger(category: "Settings")

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteAccountConfirmation = false
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
                VStack(spacing: 28) {
                    // Account Section
                    settingsSection("Account") {
                        accountRow
                    }

                    // Chef Selection
                    ChefSelectionView()
                        .padding(.horizontal, 16)

                    // Dietary Preferences
                    DietaryPreferenceSection()
                        .padding(.horizontal, 16)

                    // Subscription & Credits Section
                    settingsSection("Plan & Credits") {
                        VStack(spacing: 0) {
                            // Tier badge
                            HStack(spacing: 12) {
                                Image(systemName: EntitlementManager.shared.isSubscriber ? "crown.fill" : "sparkles")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.primary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(StoreManager.shared.currentTier.displayName)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)

                                    Text(UsageTracker.shared.creditBalanceDescription)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                Spacer()
                                if !EntitlementManager.shared.isSubscriber {
                                    Button { showPaywall = true } label: {
                                        Text("Upgrade")
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
                            }
                            .padding(14)

                            // Credit refresh countdown for subscribers
                            if let daysLeft = UsageTracker.shared.daysUntilCreditRefresh {
                                settingsDivider
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 15))
                                        .foregroundStyle(Theme.textTertiary)
                                        .frame(width: 24)
                                    Text("Credits refresh in \(daysLeft) days")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textTertiary)
                                    Spacer()
                                }
                                .padding(14)
                            }

                            // Buy more credits button
                            settingsDivider
                            settingsButton("Buy More Credits", icon: "plus.circle", color: Theme.primary) {
                                showPaywall = true
                            }

                            if EntitlementManager.shared.isSubscriber {
                                settingsDivider
                                settingsButton("Manage Subscription", icon: "creditcard", color: Theme.textPrimary) {
                                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }
                        }
                    }

                    // Notifications Section (authenticated only)
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

                    // App Section
                    settingsSection("App") {
                        VStack(spacing: 0) {
                            settingsButton("Export My Data", icon: "square.and.arrow.up", color: Theme.textPrimary) {
                                exportData()
                            }
                            settingsDivider
                            settingsLink("Privacy Policy", icon: "hand.raised", url: "https://tastethelens.com/privacy")
                            settingsDivider
                            settingsLink("Terms of Service", icon: "doc.text", url: "https://tastethelens.com/terms")
                        }
                    }

                    // Version
                    Text("Taste The Lens v\(appVersion)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textQuaternary)
                        .padding(.top, 8)

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
                        .foregroundStyle(Theme.primary)
                }
            }
            .sheet(isPresented: $showSignIn) {
                SignInView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: EntitlementManager.shared.isSubscriber ? .topUp : .outOfGenerations)
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
                        Text(authManager.email)
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
        async let subscriptionTask: () = StoreManager.shared.updateSubscriptionStatus()
        _ = await (creditsTask, usageTask, subscriptionTask)
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
            subscriptionTier: StoreManager.shared.currentTier.displayName
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
