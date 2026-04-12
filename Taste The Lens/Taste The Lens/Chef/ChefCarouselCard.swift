import SwiftUI

struct ChefCarouselCard: View {
    let chef: ChefPersonality
    let isSelected: Bool
    let isLocked: Bool
    var onSelect: () -> Void = {}

    private var chefTheme: ChefTheme { chef.theme }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                heroImage
                cardContent
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.darkCardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? chefTheme.accent.opacity(0.7) : chefTheme.accent.opacity(0.2),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(
                color: isSelected ? chefTheme.accent.opacity(0.3) : .clear,
                radius: 16, y: 4
            )
            .opacity(isLocked ? 0.55 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        Color.clear
            .frame(height: 220)
            .overlay {
                if let uiImage = UIImage(named: chef.avatarImageName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // SF Symbol fallback for chefs without avatar assets
                    chefTheme.heroGradient
                        .overlay {
                            Image(systemName: chef.icon)
                                .font(.system(size: 56, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                // Chef icon badge
                Circle()
                    .fill(chefTheme.accent.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: chef.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    )
                    .padding(12)
            }
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Circle().fill(.black.opacity(0.5)))
                        .padding(12)
                }
            }
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 20
            ))
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Name + subtitle
            VStack(alignment: .center, spacing: 4) {
                Text(chef.displayName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.darkTextPrimary)

                Text(chef.subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(chefTheme.accent)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(Theme.darkCardBorder)
                .frame(height: 0.5)

            // Best for
            VStack(alignment: .leading, spacing: 8) {
                ForEach(chef.bestFor) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(chefTheme.accent)
                            .frame(width: 18)

                        Text(item.text)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.darkTextSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }
}

#Preview {
    ZStack {
        Theme.darkBg.ignoresSafeArea()

        ChefCarouselCard(
            chef: .defaultChef,
            isSelected: true,
            isLocked: false
        )
        .frame(width: 300)
        .padding()
    }
}
