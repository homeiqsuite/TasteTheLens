import SwiftUI
import SwiftData
import Auth
import os

private let logger = makeLogger(category: "TastingMenuDetail")

struct TastingMenuDetailView: View {
    let menu: TastingMenuDTO

    @Environment(\.modelContext) private var modelContext
    @State private var courses: [MenuCourseDTO] = []
    @State private var participants: [MenuParticipantDTO] = []
    @State private var remoteRecipes: [String: Recipe] = [:]
    @State private var isLoading = true
    @State private var isPublishing = false
    @State private var selectedRecipe: Recipe?
    @State private var showPublished = false
    @State private var showQRCode = false
    // #6: Track current invite code locally (can change after revoke)
    @State private var currentInviteCode: String
    @State private var isRevokingInvite = false
    @State private var showRevokeConfirmation = false

    private let menuService = TastingMenuService.shared
    private let authManager = AuthManager.shared

    init(menu: TastingMenuDTO) {
        self.menu = menu
        self._currentInviteCode = State(initialValue: menu.inviteCode)
    }

    private var isCreator: Bool {
        authManager.currentUser?.id.uuidString == menu.creatorId
    }

    private var isPublished: Bool { menu.status == "published" }

    private var filledCourses: Int {
        courses.filter { $0.recipeId != nil }.count
    }

    private var allCoursesFilled: Bool {
        !courses.isEmpty && filledCourses == courses.count
    }

    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(Theme.gold)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        participantsSection
                        coursesSection

                        if isCreator && allCoursesFilled && !isPublished {
                            publishButton
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle(menu.theme)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.darkBg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                toolbarActions
            }
        }
        .sheet(item: $selectedRecipe) { recipe in
            NavigationStack {
                RecipeCardView(recipe: recipe)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { selectedRecipe = nil }
                                .foregroundStyle(Theme.gold)
                        }
                    }
            }
        }
        .sheet(isPresented: $showQRCode) {
            if let url = DeepLinkHandler.url(forMenuInvite: currentInviteCode) {
                QRCodeSheet(url: url)
            }
        }
        .navigationDestination(isPresented: $showPublished) {
            // #10: Pass pre-fetched remoteRecipes to avoid double-downloading
            PublishedMenuView(menu: menu, courses: courses, preloadedRecipes: remoteRecipes)
        }
        .alert("Revoke Invite Link?", isPresented: $showRevokeConfirmation) {
            Button("Revoke & Regenerate", role: .destructive) {
                Task { await revokeInvite() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The current invite link will stop working. A new one will be generated with a 7-day expiry.")
        }
        .task {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuCourseUpdated)) { notification in
            if let menuId = notification.userInfo?["menuId"] as? String, menuId == menu.id {
                Task { await loadData() }
            }
        }
        .onAppear {
            menuService.subscribeToMenu(id: menu.id)
        }
        .onDisappear {
            menuService.unsubscribeFromMenu(id: menu.id)
        }
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var toolbarActions: some View {
        HStack(spacing: 4) {
            if isPublished {
                // #21: Published menus show "Share Menu" instead of share invite
                Button {
                    shareMenuSummary()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Theme.gold)
                }
            } else {
                // #17: QR code button
                Button {
                    showQRCode = true
                } label: {
                    Image(systemName: "qrcode")
                        .foregroundStyle(Theme.gold)
                }

                // Share invite link
                Button {
                    shareInvite()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Theme.gold)
                }

                // #6: Creator options menu (revoke invite)
                if isCreator {
                    Menu {
                        Button(role: .destructive) {
                            showRevokeConfirmation = true
                        } label: {
                            Label("Revoke Invite Link", systemImage: "link.badge.minus")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Theme.gold)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(menu.theme)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(Theme.gold)

            HStack(spacing: 16) {
                Label("\(courses.count) courses", systemImage: "menucard")
                Label("\(participants.count) chefs", systemImage: "person.2")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.darkTextTertiary)

            // Show event date if set
            if let eventDateStr = menu.eventDate,
               let eventDate = ISO8601DateFormatter().date(from: eventDateStr) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text(eventDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 13))
                }
                .foregroundStyle(Theme.gold.opacity(0.8))
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.darkStroke)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.gold)
                        .frame(width: courses.isEmpty ? 0 : geo.size.width * CGFloat(filledCourses) / CGFloat(courses.count), height: 6)
                        .animation(.easeInOut(duration: 0.4), value: filledCourses)
                }
            }
            .frame(height: 6)
            .padding(.top, 4)

            Text("\(filledCourses)/\(courses.count) courses filled")
                .font(.system(size: 11))
                .foregroundStyle(Theme.darkTextHint)
        }
        .glassCard()
    }

    // MARK: - Participants

    private var participantsSection: some View {
        HStack(spacing: -8) {
            ForEach(Array(participants.enumerated()), id: \.element.userId) { index, participant in
                Circle()
                    .fill(participantColor(index))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(participant.role == "creator" ? "C" : "\(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.darkTextPrimary)
                    )
                    .overlay(
                        Circle()
                            .stroke(Theme.darkBg, lineWidth: 2)
                    )
            }
            Spacer()

            if !isPublished {
                Text("Share invite to add chefs")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.darkTextHint)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Courses

    private var coursesSection: some View {
        VStack(spacing: 12) {
            ForEach(courses) { course in
                if course.recipeId != nil {
                    filledCourseCard(course)
                } else {
                    emptyCourseCard(course)
                }
            }
        }
    }

    private func filledCourseCard(_ course: MenuCourseDTO) -> some View {
        let recipeId = course.recipeId!
        let localRecipe = try? modelContext.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.remoteId == recipeId })).first
        let recipe = localRecipe ?? remoteRecipes[recipeId]

        return Button {
            loadRecipe(id: recipeId)
        } label: {
            HStack(spacing: 14) {
                recipeThumb(recipeId: recipeId)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(course.courseType)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.gold.opacity(0.7))

                    Text(recipe?.dishName ?? "Course \(course.courseOrder + 1)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.darkTextPrimary)

                    // #19: Show participant with their color dot
                    if let participantId = course.participantId {
                        HStack(spacing: 5) {
                            let idx = participants.firstIndex(where: { $0.userId == participantId }) ?? 0
                            Circle()
                                .fill(participantColor(idx))
                                .frame(width: 8, height: 8)
                            Text(participantLabel(participantId))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.darkTextTertiary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.darkTextHint)
            }
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    private func emptyCourseCard(_ course: MenuCourseDTO) -> some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // #23: Allow creator to edit course type via Menu picker
                    if isCreator && !isPublished {
                        Menu {
                            ForEach(CourseType.allCases) { type in
                                Button(type.displayName) {
                                    Task { await updateCourseType(course, to: type) }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(course.courseType)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.gold.opacity(0.7))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.gold.opacity(0.5))
                            }
                        }
                    } else {
                        Text(course.courseType)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.gold.opacity(0.7))
                    }

                    Text("Course \(course.courseOrder + 1)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.darkTextTertiary)
                }
                Spacer()

                Image(systemName: CourseType(rawValue: course.courseType)?.icon ?? "fork.knife")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.darkTextHint)
            }

            if !isPublished {
                Button {
                    addCourse(course)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12))
                        Text("Add Course")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Theme.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.gold.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    )
                }
            }
        }
        .padding(16)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.darkStroke, style: StrokeStyle(lineWidth: 1, dash: [8, 6]))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Theme.darkSurface)
                )
        )
    }

    // MARK: - Publish

    private var publishButton: some View {
        Button {
            Task { await publishMenu() }
        } label: {
            HStack {
                if isPublishing { ProgressView().tint(Theme.darkBg) }
                Text(isPublishing ? "Publishing..." : "Publish Menu")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(Theme.darkBg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isPublishing)
    }

    // MARK: - Helpers

    @MainActor
    private func loadData() async {
        do {
            async let coursesResult = menuService.fetchCourses(menuId: menu.id)
            async let participantsResult = menuService.fetchParticipants(menuId: menu.id)
            courses = try await coursesResult
            participants = try await participantsResult
        } catch {
            logger.error("Failed to load menu data: \(error)")
        }

        do {
            let fetched = try await menuService.fetchMenuRecipes(menuId: menu.id)
            remoteRecipes = fetched
        } catch {
            logger.error("Failed to fetch remote recipes: \(error)")
        }

        isLoading = false
    }

    private func addCourse(_ course: MenuCourseDTO) {
        guard authManager.isAuthenticated else { return }
        NotificationCenter.default.post(
            name: .addMenuCourse,
            object: nil,
            userInfo: ["menuId": menu.id, "courseOrder": course.courseOrder, "courseType": course.courseType]
        )
    }

    private func publishMenu() async {
        isPublishing = true
        do {
            try await menuService.publishMenu(id: menu.id)
            HapticManager.success()
            showPublished = true
        } catch let error as TastingMenuError {
            logger.error("Failed to publish: \(error.localizedDescription)")
        } catch {
            logger.error("Failed to publish menu: \(error)")
        }
        isPublishing = false
    }

    private func shareInvite() {
        if let url = DeepLinkHandler.url(forMenuInvite: currentInviteCode) {
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            presentActivityVC(activityVC)
        }
    }

    // #21: Share a text summary for published menus
    private func shareMenuSummary() {
        let courseList = courses.enumerated().map { i, course in
            let recipeId = course.recipeId ?? ""
            let localRecipe = try? modelContext.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.remoteId == recipeId })).first
            let recipe = localRecipe ?? remoteRecipes[recipeId]
            return "\(i + 1). \(course.courseType): \(recipe?.dishName ?? "TBD")"
        }.joined(separator: "\n")

        let summary = "\(menu.theme)\nA \(courses.count)-Course Tasting Menu\n\n\(courseList)\n\nCreated with Taste The Lens"
        let activityVC = UIActivityViewController(activityItems: [summary], applicationActivities: nil)
        presentActivityVC(activityVC)
    }

    // #6: Revoke and regenerate invite code
    private func revokeInvite() async {
        isRevokingInvite = true
        do {
            let newCode = try await menuService.revokeAndRegenerateInvite(menuId: menu.id)
            currentInviteCode = newCode
            HapticManager.success()
        } catch {
            logger.error("Failed to revoke invite: \(error)")
        }
        isRevokingInvite = false
    }

    // #23: Update course type
    private func updateCourseType(_ course: MenuCourseDTO, to type: CourseType) async {
        do {
            try await menuService.updateCourseType(menuId: menu.id, courseOrder: course.courseOrder, courseType: type)
            // Refresh course list to reflect the change
            if let index = courses.firstIndex(where: { $0.id == course.id }) {
                let updated = MenuCourseDTO(
                    id: course.id,
                    menuId: course.menuId,
                    participantId: course.participantId,
                    recipeId: course.recipeId,
                    courseType: type.rawValue,
                    courseOrder: course.courseOrder,
                    addedAt: course.addedAt
                )
                courses[index] = updated
            }
        } catch {
            logger.error("Failed to update course type: \(error)")
        }
    }

    private func loadRecipe(id: String) {
        let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.remoteId == id })
        if let recipe = try? modelContext.fetch(descriptor).first {
            selectedRecipe = recipe
        } else if let recipe = remoteRecipes[id] {
            selectedRecipe = recipe
        }
    }

    @ViewBuilder
    private func recipeThumb(recipeId: String) -> some View {
        let localRecipe = try? modelContext.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.remoteId == recipeId })).first
        let recipe = localRecipe ?? remoteRecipes[recipeId]

        if let recipe,
           let imageData = recipe.generatedDishImageData,
           let image = UIImage(data: imageData) {
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.darkSurface)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(Theme.darkTextHint)
                )
        }
    }

    private func participantColor(_ index: Int) -> Color {
        let colors: [Color] = [Theme.gold, Theme.visual, .purple, .orange, .pink]
        return colors[index % colors.count]
    }

    private func participantLabel(_ userId: String) -> String {
        if userId == menu.creatorId { return "Creator" }
        if let index = participants.firstIndex(where: { $0.userId == userId }) {
            return "Chef \(index + 1)"
        }
        return "Chef"
    }

    private func presentActivityVC(_ activityVC: UIActivityViewController) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           var topVC = windowScene.windows.first?.rootViewController {
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let addMenuCourse = Notification.Name("addMenuCourse")
}
