import SwiftUI

struct AuthPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSignIn = false

    private let gold = Theme.gold

    var body: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 12)

            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 5)

            Spacer().frame(height: 8)

            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 36))
                .foregroundStyle(gold)

            Text("Save to the Cloud?")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.darkTextPrimary)

            Text("Sign in to sync your recipes across devices and never lose a dish.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.darkTextTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer().frame(height: 8)

            Button {
                showSignIn = true
            } label: {
                Text("Sign In to Save")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(gold)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            Button {
                dismiss()
            } label: {
                Text("Maybe Later")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.darkTextTertiary)
            }

            Spacer().frame(height: 12)
        }
        .background(Theme.darkBg)
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }
}
