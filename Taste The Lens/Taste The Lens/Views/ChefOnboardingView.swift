import SwiftUI

struct ChefOnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("selectedChef") private var selectedChef = "default"

    @State private var showContent = false

    var body: some View {
        ZStack {
            Theme.darkBg
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Header — gold serif title
                VStack(spacing: 10) {
                    Text("Choose Your Chef")
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(Theme.gold)

                    Text("Pick who's cooking for you. You can switch anytime.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.darkTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

                // Chef cards
                VStack(spacing: 14) {
                    ForEach(ChefPersonality.allCases.filter { $0 != .custom }) { chef in
                        chefCard(chef)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // CTA — "Choose Chef"
                Button {
                    HapticManager.medium()
                    withAnimation(.easeOut(duration: 0.4)) {
                        isPresented = false
                    }
                } label: {
                    Text("Choose Chef")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Theme.darkBg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [Theme.gold, Theme.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Theme.gold.opacity(0.35), radius: 14, y: 5)
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

    private func chefCard(_ chef: ChefPersonality) -> some View {
        let isSelected = selectedChef == chef.rawValue

        return Button {
            HapticManager.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedChef = chef.rawValue
            }
        } label: {
            HStack(spacing: 0) {
                // Avatar — image with SF Symbol fallback
                chefAvatar(chef, isSelected: isSelected)
                    .padding(.trailing, 14)

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text(chef.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isSelected ? Theme.darkTextPrimary : Theme.darkTextPrimary.opacity(0.85))

                    Text(chef.subtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? Theme.gold : Theme.darkTextSecondary)

                    if isSelected {
                        Text(chef.tagline)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.darkTextTertiary)
                            .lineLimit(1)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.gold)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Theme.glassCardFill : Theme.glassCardFill.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? Theme.gold : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            // Gold glow on selected card
            .shadow(
                color: isSelected ? Theme.gold.opacity(0.25) : .clear,
                radius: isSelected ? 12 : 0,
                y: 2
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .opacity(isSelected ? 1.0 : 0.7)
        }
        .buttonStyle(.plain)
    }

    private func chefAvatar(_ chef: ChefPersonality, isSelected: Bool) -> some View {
        Group {
            if let uiImage = UIImage(named: chef.avatarImageName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                // SF Symbol fallback
                Image(systemName: chef.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.gold : Theme.darkTextTertiary)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? Theme.gold.opacity(0.15) : Theme.darkSurface)
                    )
            }
        }
    }
}
