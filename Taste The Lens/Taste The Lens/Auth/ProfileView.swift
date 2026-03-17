import SwiftUI
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "Profile")

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var showSignOut = false

    private let authManager = AuthManager.shared
    private let bg = Color(red: 0.051, green: 0.051, blue: 0.059)
    private let gold = Color(red: 0.788, green: 0.659, blue: 0.298)

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
                            .foregroundStyle(.white)

                        Text(authManager.email)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.4))

                        Text("Member since \(authManager.memberSinceDate.formatted(.dateTime.month(.wide).year()))")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
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
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                        }

                        Divider().background(Color.white.opacity(0.08)).padding(.leading, 50)

                        Button {
                            showDeleteConfirmation = true
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
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
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
                Text("Your local recipes will remain on this device.")
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                    Task {
                        do {
                            try await authManager.deleteAccount()
                            dismiss()
                        } catch {
                            logger.error("Delete account failed: \(error)")
                        }
                    }
                }
            } message: {
                Text("This will permanently delete your account and all cloud data. Local recipes on this device will not be affected. This cannot be undone.")
            }
        }
    }
}
