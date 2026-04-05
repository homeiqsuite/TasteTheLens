import SwiftUI
import Supabase

extension Notification.Name {
    static let displayNameDismissedWithoutSaving = Notification.Name("displayNameDismissedWithoutSaving")
}

struct DisplayNamePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let authManager = AuthManager.shared
    private let maxNameLength = 20

    /// Characters allowed in display names: letters, numbers, spaces, hyphens, underscores
    private let allowedCharacterSet: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: " -_")
        return set
    }()

    /// Basic blocklist of offensive words
    private let blockedWords: Set<String> = [
        "fuck", "shit", "ass", "bitch", "dick", "cock", "pussy", "cunt",
        "nigger", "nigga", "faggot", "retard", "slut", "whore",
        "nazi", "hitler", "kill", "rape"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer().frame(height: 40)

                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.gold)

                        Text("What should we call you?")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.darkTextPrimary)

                        Text("This name will be shown on your challenge submissions")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.darkTextTertiary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 6) {
                        ZStack(alignment: .leading) {
                            if name.isEmpty {
                                Text("Display Name")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .allowsHitTesting(false)
                            }
                            TextField("", text: $name)
                                .textContentType(.name)
                                .autocorrectionDisabled()
                                .foregroundStyle(Theme.darkTextPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Theme.darkStroke)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.darkStroke, lineWidth: 0.5)
                        )

                        HStack {
                            Spacer()
                            Text("\(name.count)/\(maxNameLength)")
                                .font(.system(size: 12))
                                .foregroundStyle(name.count >= maxNameLength ? .red.opacity(0.8) : Theme.darkTextTertiary)
                        }
                    }
                    .padding(.horizontal, 32)

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(.horizontal, 32)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .tint(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Continue")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .background(Theme.gold)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        NotificationCenter.default.post(
                            name: .displayNameDismissedWithoutSaving,
                            object: nil
                        )
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.darkTextTertiary)
                    }
                    .accessibilityLabel("Dismiss")
                }
            }
            .onChange(of: name) { _, newValue in
                if newValue.count > maxNameLength {
                    name = String(newValue.prefix(maxNameLength))
                }
            }
        }
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Minimum length
        guard trimmed.count >= 2 else {
            errorMessage = "Name must be at least 2 characters."
            return
        }

        // Character validation
        guard trimmed.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            errorMessage = "Only letters, numbers, spaces, hyphens, and underscores are allowed."
            return
        }

        // Profanity check
        let lowered = trimmed.lowercased()
        let words = lowered.components(separatedBy: .whitespaces)
        if words.contains(where: { blockedWords.contains($0) }) || blockedWords.contains(where: { lowered.contains($0) }) {
            errorMessage = "That name contains inappropriate language. Please choose another."
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // Server-side uniqueness check
        do {
            let isUnique = try await checkDisplayNameUniqueness(trimmed)
            if !isUnique {
                errorMessage = "That name is already taken. Please choose another."
                return
            }
        } catch {
            // If uniqueness check fails, proceed anyway — server will enforce
        }

        do {
            try await authManager.updateDisplayName(trimmed)
            dismiss()
        } catch {
            errorMessage = "Failed to save. Please try again."
        }
    }

    private func checkDisplayNameUniqueness(_ name: String) async throws -> Bool {
        struct NameCheck: Decodable { let display_name: String? }
        let response = try await SupabaseManager.shared.client
            .from("users")
            .select("display_name")
            .ilike("display_name", value: name)
            .limit(1)
            .execute()
        let matches = try JSONDecoder().decode([NameCheck].self, from: response.data)
        return matches.isEmpty
    }
}
