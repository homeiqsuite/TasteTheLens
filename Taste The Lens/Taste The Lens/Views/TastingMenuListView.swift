import SwiftUI
import Auth
import os

private let logger = makeLogger(category: "TastingMenuList")

struct TastingMenuListView: View {
    var initialInviteCode: String?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var showCreateMenu = false
    @State private var inviteCode = ""
    @State private var joinError: String?
    @State private var isJoining = false
    @State private var menuToDelete: TastingMenuDTO?
    @State private var menuToLeave: TastingMenuDTO?
    @State private var showDeleteConfirmation = false
    @State private var showLeaveConfirmation = false
    // #24: Cache participant counts for delete confirmation
    @State private var participantCounts: [String: Int] = [:]

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
            .onAppear {
                if let code = initialInviteCode, !code.isEmpty {
                    inviteCode = code
                    selectedTab = 1
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
                        .contextMenu {
                            let isCreator = menu.creatorId == authManager.currentUser?.id.uuidString

                            if isCreator {
                                Button(role: .destructive) {
                                    menuToDelete = menu
                                    showDeleteConfirmation = true
                                    // #24: Pre-fetch participant count for warning message
                                    Task { await prefetchParticipantCount(menu) }
                                } label: {
                                    Label("Delete Menu", systemImage: "trash")
                                }
                            } else {
                                // #22: Participants can leave the menu
                                Button(role: .destructive) {
                                    menuToLeave = menu
                                    showLeaveConfirmation = true
                                } label: {
                                    Label("Leave Menu", systemImage: "person.badge.minus")
                                }
                            }
                        }
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
        // #24: Delete confirmation with participant count warning
        .alert("Delete Menu", isPresented: $showDeleteConfirmation, presenting: menuToDelete) { menu in
            Button("Delete", role: .destructive) {
                Task {
                    try? await menuService.deleteMenu(id: menu.id)
                    HapticManager.success()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { menu in
            let count = participantCounts[menu.id] ?? 0
            let otherChefs = count > 1 ? count - 1 : 0
            if otherChefs > 0 {
                Text("Deleting \"\(menu.theme)\" will also remove \(otherChefs) other chef\(otherChefs == 1 ? "" : "s") from the menu. This cannot be undone.")
            } else {
                Text("Are you sure you want to delete \"\(menu.theme)\"? This cannot be undone.")
            }
        }
        // #22: Leave confirmation
        .alert("Leave Menu", isPresented: $showLeaveConfirmation, presenting: menuToLeave) { menu in
            Button("Leave", role: .destructive) {
                Task {
                    do {
                        try await menuService.leaveMenu(id: menu.id)
                        HapticManager.success()
                    } catch {
                        logger.error("Failed to leave menu: \(error)")
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { menu in
            Text("You'll be removed from \"\(menu.theme)\" and any course you added will remain. You can rejoin with an invite link.")
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

                // Show event date if set
                if let eventDateStr = menu.eventDate,
                   let eventDate = ISO8601DateFormatter().date(from: eventDateStr) {
                    Label(eventDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                }

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
        Text(statusLabel(status))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(statusColor(status).opacity(0.15)))
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "draft": return "Draft"
        case "in_progress": return "In Progress"
        case "published": return "Published"
        default: return status.capitalized
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "draft": Theme.darkTextTertiary
        case "in_progress": Theme.gold
        case "published": Theme.visual
        default: Theme.darkTextHint
        }
    }

    // #24
    private func prefetchParticipantCount(_ menu: TastingMenuDTO) async {
        if let participants = try? await menuService.fetchParticipants(menuId: menu.id) {
            participantCounts[menu.id] = participants.count
        }
    }

    // MARK: - Join Tab (#18)

    private var joinTab: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 8)

                // Illustration + heading
                VStack(spacing: 12) {
                    Image(systemName: "person.2.badge.gearshape")
                        .font(.system(size: 52))
                        .foregroundStyle(Theme.gold.opacity(0.7))

                    Text("Join a Tasting Menu")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.darkTextPrimary)

                    Text("Enter the invite code shared by the menu creator to join their collaborative dinner.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.darkTextTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }

                // How it works steps
                howItWorksSection

                // Input and button
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Invite Code")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.darkTextTertiary)
                            Spacer()
                            Text("e.g. a3f9b2c1")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.darkTextHint)
                        }

                        TextField("Enter invite code", text: $inviteCode)
                            .font(.system(size: 16, design: .monospaced))
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
                    }

                    Button {
                        if authManager.isAuthenticated {
                            Task { await joinWithCode() }
                        } else {
                            joinError = "Sign in to join a tasting menu"
                        }
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
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How it works")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.darkTextTertiary)
                .textCase(.uppercase)
                .tracking(1)

            ForEach([
                ("1", "Get an invite code from a friend who created a tasting menu"),
                ("2", "Enter the code above and tap Join Menu"),
                ("3", "Capture a photo to add your course to the menu"),
            ], id: \.0) { step, desc in
                HStack(alignment: .top, spacing: 12) {
                    Text(step)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.darkBg)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Theme.gold))

                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.darkTextTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.darkSurface)
        )
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
            let msg = error.localizedDescription
            if msg.contains("expired") {
                joinError = "This invite link has expired. Ask the menu creator for a new one."
            } else if msg.contains("published") {
                joinError = "This menu has already been published and is no longer accepting new chefs."
            } else {
                joinError = "Invalid invite code or menu not found."
            }
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
