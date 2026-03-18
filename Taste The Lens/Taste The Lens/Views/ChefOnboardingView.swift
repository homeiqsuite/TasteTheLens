import SwiftUI

struct ChefOnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("selectedChef") private var selectedChef = "default"

    @State private var showContent = false

    var body: some View {
        ZStack {
            Theme.darkBg
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Header
                VStack(spacing: 10) {
                    Text("Choose Your Chef")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.darkTextPrimary)

                    Text("Pick who's cooking for you. You can switch anytime.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                // Chef cards
                VStack(spacing: 12) {
                    ForEach(ChefPersonality.allCases) { chef in
                        chefOption(chef)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // CTA button
                Button {
                    HapticManager.medium()
                    withAnimation(.easeOut(duration: 0.4)) {
                        isPresented = false
                    }
                } label: {
                    Text("Let's Cook")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.darkBg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.gold)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
        }
    }

    private func chefOption(_ chef: ChefPersonality) -> some View {
        let isSelected = selectedChef == chef.rawValue

        return Button {
            HapticManager.light()
            selectedChef = chef.rawValue
        } label: {
            HStack(spacing: 14) {
                Image(systemName: chef.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.gold : Theme.darkTextTertiary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(isSelected ? Theme.gold.opacity(0.15) : Theme.darkSurface)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(chef.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.darkTextPrimary)

                    Text(chef.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? Theme.gold : Theme.darkTextSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.gold)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.glassCardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.gold : Theme.darkStroke, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: selectedChef)
    }
}
