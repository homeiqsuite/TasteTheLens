import SwiftUI
import os

private let logger = makeLogger(category: "CreateMenu")

struct CreateMenuView: View {
    var onCreated: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var theme = ""
    @State private var courseCount = 3
    @State private var courseTypes: [CourseType] = [.appetizer, .main, .dessert]
    @State private var isCreating = false
    @State private var createdInviteCode: String?

    private let menuService = TastingMenuService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        if let code = createdInviteCode {
                            successView(code: code)
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

    // MARK: - Success

    private func successView(code: String) -> some View {
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

            // Invite link
            VStack(spacing: 8) {
                Text("Invite Code")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.darkTextTertiary)

                Text(code)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.gold)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Theme.darkSurface)
                    )
            }

            // Share button
            Button {
                if let url = DeepLinkHandler.url(forMenuInvite: code) {
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
                courseTypes: Array(courseTypes.prefix(courseCount))
            )
            HapticManager.success()
            createdInviteCode = menu.inviteCode
        } catch {
            logger.error("Failed to create menu: \(error)")
        }
        isCreating = false
    }
}
