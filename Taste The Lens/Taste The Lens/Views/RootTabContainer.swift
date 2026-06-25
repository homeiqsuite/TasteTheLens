import SwiftUI

/// Hosts the three home destinations (Home / Saved / Profile) behind a floating
/// tab bar + camera FAB.
///
/// Only shown while `vm.currentScreen == .dashboard`; the camera, processing,
/// and recipe-card screens still take over the full screen via `AppScreen`, so
/// the tab bar naturally disappears for those flows.
struct RootTabContainer: View {
    @Bindable var vm: MainViewModel
    @Binding var selectedTab: AppTab
    @AppStorage("selectedChef") private var selectedChef = "default"

    private var chefTheme: ChefTheme {
        (ChefPersonality(rawValue: selectedChef) ?? .defaultChef).theme
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            chefTheme.dashboardBg.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .home:
                    DashboardView(vm: vm)
                case .saved:
                    SavedRecipesView(vm: vm)
                case .profile:
                    ProfileTabView(vm: vm)
                }
            }

            BottomTabBar(selection: $selectedTab, theme: chefTheme) {
                vm.navigateToCamera()
            }
            .padding(.bottom, 6)
        }
        .onChange(of: vm.requestedTab) { _, newTab in
            guard let newTab else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = newTab
            }
            vm.requestedTab = nil
        }
    }
}

// MARK: - Profile Tab

/// Lightweight, theme-aware account hub. Surfaces the user's identity and
/// routes into the existing account / settings screens rather than duplicating
/// their functionality.
private struct ProfileTabView: View {
    @Bindable var vm: MainViewModel
    @AppStorage("selectedChef") private var selectedChef = "default"
    @State private var showSignIn = false
    @State private var showAccount = false

    private let authManager = AuthManager.shared

    private var chefTheme: ChefTheme {
        (ChefPersonality(rawValue: selectedChef) ?? .defaultChef).theme
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                actionsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 32)
            .padding(.bottom, DS.tabBarClearance + DS.Spacing.lg)
        }
        .background(chefTheme.dashboardBg.ignoresSafeArea())
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
        .sheet(isPresented: $showAccount) {
            ProfileView()
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(chefTheme.accent.opacity(0.15))
                .frame(width: 84, height: 84)
                .overlay {
                    if authManager.isAuthenticated {
                        Text(String(authManager.displayName.prefix(1)).uppercased())
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(chefTheme.accent)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(chefTheme.accent)
                    }
                }

            Text(authManager.isAuthenticated ? authManager.displayName : "Welcome, Chef")
                .font(.dsTitle)
                .foregroundStyle(chefTheme.textPrimary)

            Text(authManager.isAuthenticated
                 ? authManager.email
                 : "Sign in to sync your recipes across devices")
                .font(.dsBody)
                .foregroundStyle(chefTheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionsCard: some View {
        VStack(spacing: 0) {
            if authManager.isAuthenticated {
                profileRow(icon: "person.crop.circle", title: "Account") {
                    showAccount = true
                }
            } else {
                profileRow(icon: "person.crop.circle.badge.plus", title: "Sign In") {
                    showSignIn = true
                }
            }

            Rectangle()
                .fill(chefTheme.cardBorder.opacity(0.6))
                .frame(height: DS.Stroke.hairline)
                .padding(.leading, 60)

            profileRow(icon: "gearshape.fill", title: "Settings & Preferences") {
                vm.showSettings = true
            }
        }
        .minimalCard(chefTheme, padding: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }

    private func profileRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(chefTheme.accent)
                    .frame(width: 30)

                Text(title)
                    .font(.dsBodyEmph)
                    .foregroundStyle(chefTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(chefTheme.textQuaternary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
