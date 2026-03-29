import SwiftUI

struct DisplayNamePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let authManager = AuthManager.shared

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

                    TextField("Display Name", text: $name)
                        .textFieldStyle(AuthTextFieldStyle())
                        .textContentType(.name)
                        .autocorrectionDisabled()
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
        }
        .interactiveDismissDisabled()
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            try await authManager.updateDisplayName(trimmed)
            dismiss()
        } catch {
            errorMessage = "Failed to save. Please try again."
        }
    }
}
