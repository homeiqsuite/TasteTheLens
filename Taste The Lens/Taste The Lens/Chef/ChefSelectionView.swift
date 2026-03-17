import SwiftUI

struct ChefSelectionView: View {
    @AppStorage("selectedChef") private var selectedChef = "default"

    private let gold = Color(red: 0.788, green: 0.659, blue: 0.298)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Chef")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1.2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ChefPersonality.allCases) { chef in
                        chefCard(chef)
                    }
                }
            }
        }
    }

    private func chefCard(_ chef: ChefPersonality) -> some View {
        let isSelected = selectedChef == chef.rawValue

        return Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            selectedChef = chef.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: chef.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? gold : .white.opacity(0.5))

                    Text(chef.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                }

                Text(chef.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? gold : .white.opacity(0.4))

                Text(chef.description)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(width: 200, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? gold : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ChefSelectionView()
        .padding()
        .background(Color(red: 0.051, green: 0.051, blue: 0.059))
}
