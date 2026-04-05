import SwiftUI
import SwiftData
import os

private let logger = makeLogger(category: "Profile")

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeletionSheet = false
    @State private var showSignOut = false

    private let authManager = AuthManager.shared
    private let bg = Theme.darkBg
    private let gold = Theme.gold

    private var displayEmail: String {
        authManager.email.hasSuffix("@privaterelay.appleid.com")
            ? "Private Email (via Apple)"
            : authManager.email
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar + Info
                    VStack(spacing: 12) {
                        Circle()
                            .fill(gold.opacity(0.2))
                            .frame(width: 72, height: 72)
                            .overlay {
                                Text(String(authManager.displayName.prefix(1)).uppercased())
                                    .font(.system(size: 28, weight: .bold, design: .serif))
                                    .foregroundStyle(gold)
                            }

                        Text(authManager.displayName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Theme.darkTextPrimary)

                        HStack(spacing: 4) {
                            if authManager.email.hasSuffix("@privaterelay.appleid.com") {
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 12))
                            }
                            Text(displayEmail)
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(Theme.darkTextTertiary)

                        Text("Member since \(authManager.memberSinceDate.formatted(.dateTime.month(.wide).year()))")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.darkTextHint)
                    }
                    .padding(.top, 24)

                    // Actions
                    VStack(spacing: 0) {
                        Button {
                            showSignOut = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 15))
                                Text("Sign Out")
                                    .font(.system(size: 15))
                                Spacer()
                            }
                            .foregroundStyle(Theme.darkTextSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                        }

                        Divider().background(Theme.darkStroke).padding(.leading, 50)

                        Button {
                            showDeletionSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 15))
                                Text("Delete Account")
                                    .font(.system(size: 15))
                                Spacer()
                            }
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.darkSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.darkStroke, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 16)
                }
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(gold)
                }
            }
            .alert("Sign Out", isPresented: $showSignOut) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authManager.signOut()
                        dismiss()
                    }
                }
            } message: {
                Text("You'll stay signed in on other devices. Your local recipes will remain on this device.")
            }
            .sheet(isPresented: $showDeletionSheet) {
                AccountDeletionSheet(modelContext: modelContext) {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Account Deletion Sheet

private struct AccountDeletionSheet: View {
    let modelContext: ModelContext
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var exportFileURL: URL?
    @State private var showExportShare = false

    private let authManager = AuthManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Warning icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.red.opacity(0.8))
                        .padding(.top, 24)

                    Text("Delete Your Account")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.darkTextPrimary)

                    Text("This will permanently delete your account and all cloud data. Local recipes on this device will not be affected. This cannot be undone.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.darkTextTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Export data first
                    Button {
                        exportData()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                            Text("Export My Data First")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(Theme.gold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(Theme.gold, lineWidth: 1)
                        )
                    }

                    // Confirmation field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type DELETE to confirm")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.darkTextTertiary)

                        TextField("", text: $confirmationText)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.darkTextPrimary)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Theme.darkSurface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(confirmationText == "DELETE" ? .red.opacity(0.6) : Theme.darkStroke, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                    }

                    // Delete button
                    Button {
                        deleteAccount()
                    } label: {
                        HStack(spacing: 8) {
                            if isDeleting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isDeleting ? "Deleting..." : "Delete My Account")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(confirmationText == "DELETE" && !isDeleting ? .red : .red.opacity(0.3))
                        )
                    }
                    .disabled(confirmationText != "DELETE" || isDeleting)
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 20)
                }
            }
            .background(Theme.darkBg.ignoresSafeArea())
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
            .sheet(isPresented: $showExportShare) {
                if let url = exportFileURL {
                    ExportShareSheet(items: [url])
                }
            }
        }
    }

    private func exportData() {
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
        }
    }

    private func deleteAccount() {
        isDeleting = true
        errorMessage = nil
        Task {
            do {
                try await authManager.deleteAccount()
                dismiss()
                onDeleted()
            } catch {
                logger.error("Delete account failed: \(error)")
                errorMessage = "Failed to delete account. Please try again."
                isDeleting = false
            }
        }
    }
}

private struct ExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
