import SwiftUI
import SwiftData
import os

private let logger = makeLogger(category: "PublishedMenu")

struct PublishedMenuView: View {
    let menu: TastingMenuDTO
    let courses: [MenuCourseDTO]
    // #10: Accept pre-fetched recipes from DetailView to avoid double-downloading
    var preloadedRecipes: [String: Recipe] = [:]

    @Environment(\.modelContext) private var modelContext
    @State private var loadedRecipes: [Int: Recipe] = [:]

    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Tasting Menu")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.darkTextTertiary)
                            .textCase(.uppercase)
                            .tracking(2)

                        Text(menu.theme)
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.gold)
                            .multilineTextAlignment(.center)

                        Rectangle()
                            .fill(Theme.gold.opacity(0.3))
                            .frame(width: 60, height: 1)

                        Text("\(courses.count) Courses")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.darkTextTertiary)

                        // Show event date if set
                        if let eventDateStr = menu.eventDate,
                           let eventDate = ISO8601DateFormatter().date(from: eventDateStr) {
                            let formatted = eventDate.formatted(date: .long, time: .omitted)
                            Text(formatted)
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.gold.opacity(0.7))
                        }
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 40)

                    // Courses
                    ForEach(courses) { course in
                        courseSection(course)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.darkBg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // #21: Share menu PDF (not invite) on published menus
                    Button {
                        shareMenuPDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Theme.gold)
                    }

                    Button {
                        exportPDF()
                    } label: {
                        Image(systemName: "doc.text")
                            .foregroundStyle(Theme.gold)
                    }
                }
            }
        }
        .task {
            loadAllRecipes()
            // #10: Only fetch remotely for courses not already covered by preloaded data
            let missingIds = courses.compactMap(\.recipeId).filter { preloadedRecipes[$0] == nil }
            if !missingIds.isEmpty {
                await fetchRemoteRecipes()
            }
        }
    }

    // MARK: - Course Section

    @ViewBuilder
    private func courseSection(_ course: MenuCourseDTO) -> some View {
        VStack(spacing: 16) {
            // Course type label
            Text(course.courseType.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Theme.gold.opacity(0.6))
                .tracking(2)
                .padding(.top, 24)

            if let recipe = loadedRecipes[course.courseOrder] {
                // Dish image
                if let imageData = recipe.generatedDishImageData, let image = UIImage(data: imageData) {
                    Color.clear
                        .frame(height: 220)
                        .overlay {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Dish name
                Text(recipe.dishName)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.darkTextPrimary)
                    .multilineTextAlignment(.center)

                // Description
                Text(recipe.recipeDescription)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.darkTextTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.darkSurface)
                    .frame(height: 120)
                    .overlay(
                        Text("No recipe added")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.darkTextHint)
                    )
            }

            if course.courseOrder < courses.count - 1 {
                Rectangle()
                    .fill(Theme.darkSurface)
                    .frame(height: 1)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Helpers

    private func loadAllRecipes() {
        for course in courses {
            guard let recipeIdString = course.recipeId else { continue }

            // Check preloaded first (#10)
            if let preloaded = preloadedRecipes[recipeIdString] {
                loadedRecipes[course.courseOrder] = preloaded
                continue
            }

            // Fall back to local SwiftData
            let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.remoteId == recipeIdString })
            if let recipe = try? modelContext.fetch(descriptor).first {
                loadedRecipes[course.courseOrder] = recipe
            }
        }
    }

    private func fetchRemoteRecipes() async {
        do {
            let fetched = try await TastingMenuService.shared.fetchMenuRecipes(menuId: menu.id)

            for course in courses {
                guard let recipeId = course.recipeId,
                      loadedRecipes[course.courseOrder] == nil,
                      let recipe = fetched[recipeId] else { continue }
                loadedRecipes[course.courseOrder] = recipe
            }
        } catch {
            logger.error("Failed to fetch remote recipes: \(error)")
        }
    }

    // #21: Share a text summary of the menu (not the invite link)
    private func shareMenuPDF() {
        var courseData: [(courseType: String, recipe: Recipe)] = []
        for course in courses {
            if let recipe = loadedRecipes[course.courseOrder] {
                courseData.append((courseType: course.courseType, recipe: recipe))
            }
        }
        guard !courseData.isEmpty else { return }

        let data = PDFExporter.generateMenuPDF(theme: menu.theme, courses: courseData)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TastingMenu-\(menu.theme).pdf")
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        presentActivityVC(activityVC)
    }

    private func exportPDF() {
        var courseData: [(courseType: String, recipe: Recipe)] = []
        for course in courses {
            if let recipe = loadedRecipes[course.courseOrder] {
                courseData.append((courseType: course.courseType, recipe: recipe))
            }
        }
        guard !courseData.isEmpty else { return }

        let data = PDFExporter.generateMenuPDF(theme: menu.theme, courses: courseData)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("TastingMenu-\(menu.theme).pdf")
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        presentActivityVC(activityVC)
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
