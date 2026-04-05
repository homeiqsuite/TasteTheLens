import SwiftUI
import os

private let logger = makeLogger(category: "CreateMenu")

// #13: Menu templates
private struct MenuTemplate {
    let name: String
    let icon: String
    let themeHint: String
    let courses: [CourseType]
}

private let menuTemplates: [MenuTemplate] = [
    MenuTemplate(name: "Classic French", icon: "🥐", themeHint: "Classic French", courses: [.amuse, .soup, .main, .dessert]),
    MenuTemplate(name: "Omakase", icon: "🍣", themeHint: "Omakase", courses: [.amuse, .appetizer, .main, .dessert]),
    MenuTemplate(name: "Farm-to-Table", icon: "🌿", themeHint: "Farm-to-Table", courses: [.appetizer, .salad, .main, .dessert]),
    MenuTemplate(name: "Grand Tasting", icon: "✨", themeHint: "Grand Tasting", courses: [.amuse, .appetizer, .soup, .salad, .main, .dessert]),
]

struct CreateMenuView: View {
    var onCreated: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var theme = ""
    @State private var courseCount = 3
    @State private var courseTypes: [CourseType] = [.appetizer, .main, .dessert]
    @State private var isCreating = false
    @State private var createdMenu: TastingMenuDTO?
    // #14: Optional event date
    @State private var hasEventDate = false
    @State private var eventDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    private let menuService = TastingMenuService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        if let menu = createdMenu {
                            successView(menu: menu)
                        } else {
                            formView
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("New Tasting Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        VStack(spacing: 24) {
            // #13: Templates section
            templatesSection

            // Theme
            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.darkTextTertiary)

                TextField("e.g., Brutalist Architecture", text: $theme)
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
            }

            // Course count
            VStack(alignment: .leading, spacing: 8) {
                Text("Number of Courses")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.darkTextTertiary)

                Stepper(value: $courseCount, in: 2...6) {
                    Text("\(courseCount) courses")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.darkTextPrimary)
                }
                .tint(Theme.gold)
                .onChange(of: courseCount) { _, newCount in
                    adjustCourseTypes(to: newCount)
                }
            }
            .glassCard()

            // Course type selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Courses")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.darkTextTertiary)

                ForEach(0..<courseCount, id: \.self) { index in
                    HStack(spacing: 12) {
                        Text("Course \(index + 1)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.darkTextSecondary)
                            .frame(width: 80, alignment: .leading)

                        Picker("Type", selection: $courseTypes[index]) {
                            ForEach(CourseType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.gold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.darkSurface)
                    )
                }
            }

            // #14: Optional event date
            eventDateSection

            // Create button
            Button {
                Task { await createMenu() }
            } label: {
                HStack {
                    if isCreating { ProgressView().tint(Theme.darkBg) }
                    Text(isCreating ? "Creating..." : "Create & Invite")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Theme.darkBg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(!theme.isEmpty ? Theme.gold : Theme.gold.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(theme.isEmpty || isCreating)
        }
    }

    // MARK: - Templates (#13)

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start from a template")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.darkTextTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(menuTemplates, id: \.name) { template in
                        Button {
                            applyTemplate(template)
                        } label: {
                            VStack(spacing: 6) {
                                Text(template.icon)
                                    .font(.system(size: 24))
                                Text(template.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.darkTextSecondary)
                                Text("\(template.courses.count) courses")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.darkTextHint)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.darkSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Theme.darkStroke, lineWidth: 0.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - Event Date (#14)

    private var eventDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $hasEventDate) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set Event Date")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.darkTextPrimary)
                    Text("Optional — helps sort upcoming dinners")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.darkTextHint)
                }
            }
            .tint(Theme.gold)

            if hasEventDate {
                DatePicker(
                    "Dinner Date",
                    selection: $eventDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .tint(Theme.gold)
                .foregroundStyle(Theme.darkTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.darkSurface)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassCard()
        .animation(.easeInOut(duration: 0.2), value: hasEventDate)
    }

    // MARK: - Success

    private func successView(menu: TastingMenuDTO) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.gold)

            Text("Menu Created!")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(Theme.darkTextPrimary)

            Text("Share the invite link with friends so they can join and add courses.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.darkTextTertiary)
                .multilineTextAlignment(.center)

            // Invite code display
            VStack(spacing: 8) {
                Text("Invite Code")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.darkTextTertiary)

                Text(menu.inviteCode)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.gold)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.darkSurface)
                    )

                // Expiry note if set
                if let expiresAt = menu.inviteExpiresAt,
                   let expDate = ISO8601DateFormatter().date(from: expiresAt) {
                    Text("Expires \(expDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.darkTextHint)
                }
            }

            // Share button
            Button {
                if let url = DeepLinkHandler.url(forMenuInvite: menu.inviteCode) {
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       var topVC = windowScene.windows.first?.rootViewController {
                        while let presented = topVC.presentedViewController {
                            topVC = presented
                        }
                        topVC.present(activityVC, animated: true)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Invite Link")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Theme.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.gold.opacity(0.4), lineWidth: 1)
                )
            }

            Button {
                onCreated()
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.darkBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.top, 40)
    }

    // MARK: - Helpers

    private func applyTemplate(_ template: MenuTemplate) {
        courseCount = template.courses.count
        courseTypes = template.courses
        // Set theme hint only if field is currently empty
        if theme.isEmpty {
            theme = template.themeHint
        }
        HapticManager.light()
    }

    private func adjustCourseTypes(to count: Int) {
        let defaults: [CourseType] = [.amuse, .appetizer, .soup, .salad, .main, .dessert]
        while courseTypes.count < count {
            let next = defaults[min(courseTypes.count, defaults.count - 1)]
            courseTypes.append(next)
        }
        if courseTypes.count > count {
            courseTypes = Array(courseTypes.prefix(count))
        }
    }

    private func createMenu() async {
        isCreating = true
        do {
            let menu = try await menuService.createMenu(
                theme: theme.trimmingCharacters(in: .whitespacesAndNewlines),
                courseCount: courseCount,
                courseTypes: Array(courseTypes.prefix(courseCount)),
                eventDate: hasEventDate ? eventDate : nil
            )
            HapticManager.success()
            createdMenu = menu
        } catch {
            logger.error("Failed to create menu: \(error)")
        }
        isCreating = false
    }
}
