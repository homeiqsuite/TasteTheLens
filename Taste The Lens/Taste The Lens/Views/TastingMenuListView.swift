import SwiftUI
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "TastingMenuList")

struct TastingMenuListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showCreateMenu = false
    @State private var inviteCode = ""
    @State private var joinError: String?
    @State private var isJoining = false

    private let authManager = AuthManager.shared
    private let menuService = TastingMenuService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("Tab", selection: $selectedTab) {
                        Text("My Menus").tag(0)
                        Text("Join").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if selectedTab == 0 {
                        myMenusTab
                    } else {
                        joinTab
                    }
                }
            }
            .navigationTitle("Tasting Menus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
                if authManager.isAuthenticated {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showCreateMenu = true } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(Theme.gold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateMenu) {
                CreateMenuView {
                    Task { try? await menuService.fetchMyMenus() }
                }
            }
            .navigationDestination(for: String.self) { menuId in
                if let menu = menuService.myMenus.first(where: { $0.id == menuId }) {
                    TastingMenuDetailView(menu: menu)
                }
            }
            .task {
                if authManager.isAuthenticated {
                    try? await menuService.fetchMyMenus()
                }
            }
        }
    }

    // MARK: - My Menus

    private var myMenusTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if !authManager.isAuthenticated {
                    signInPrompt
                } else if menuService.myMenus.isEmpty {
                    emptyState
                } else {
                    ForEach(menuService.myMenus) { menu in
                        NavigationLink(value: menu.id) {
                            menuCard(menu)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .refreshable {
            try? await menuService.fetchMyMenus()
        }
    }

    private func menuCard(_ menu: TastingMenuDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(menu.theme)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.gold)
                Spacer()
                statusBadge(menu.status)
            }

            HStack(spacing: 16) {
                Label("\(menu.courseCount) courses", systemImage: "menucard")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.darkTextHint)
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.darkTextTertiary)
        }
        .glassCard()
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status.capitalized)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(statusColor(status).opacity(0.15)))
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "draft": Theme.darkTextTertiary
        case "in_progress": Theme.gold
        case "published": Theme.visual
        default: Theme.darkTextHint
        }
    }

    // MARK: - Join Tab

    private var joinTab: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "link.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Theme.darkTextHint)

            Text("Enter an invite code to join a tasting menu")
                .font(.system(size: 15))
                .foregroundStyle(Theme.darkTextTertiary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                TextField("Invite code", text: $inviteCode)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.darkSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.darkStroke, lineWidth: 0.5)
                    )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    Task { await joinWithCode() }
                } label: {
                    HStack {
                        if isJoining { ProgressView().tint(Theme.darkBg) }
                        Text(isJoining ? "Joining..." : "Join Menu")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundStyle(Theme.darkBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(!inviteCode.isEmpty ? Theme.gold : Theme.gold.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(inviteCode.isEmpty || isJoining)

                if let error = joinError {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func joinWithCode() async {
        guard authManager.isAuthenticated else {
            joinError = "Sign in to join a tasting menu"
            return
        }
        isJoining = true
        joinError = nil
        do {
            _ = try await menuService.joinMenu(inviteCode: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines))
            try? await menuService.fetchMyMenus()
            HapticManager.success()
            inviteCode = ""
            selectedTab = 0
        } catch {
            joinError = "Invalid invite code or menu not found"
        }
        isJoining = false
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "menucard")
                .font(.system(size: 48))
                .foregroundStyle(Theme.darkTextHint)
            Text("No tasting menus yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.darkTextTertiary)
            Text("Tap + to create a themed multi-course meal with friends")
                .font(.system(size: 14))
                .foregroundStyle(Theme.darkTextHint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var signInPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Theme.darkTextHint)
            Text("Sign in to create tasting menus")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.darkTextTertiary)
            Text("Collaborate with friends on themed multi-course meals")
                .font(.system(size: 14))
                .foregroundStyle(Theme.darkTextHint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
