import SwiftUI

struct ChallengeCardView: View {
    let challenge: ChallengeDTO
    @State private var dishImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Dish image
            Color.clear
                .frame(height: 180)
                .overlay {
                    if let image = dishImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Theme.darkSurface)
                            .overlay {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Theme.darkTextHint)
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                Text(challenge.title)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.gold)
                    .lineLimit(2)

                if let desc = challenge.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.darkTextTertiary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    timeRemainingPill
                    Spacer()
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 10)
        }
        .glassCard()
        .task {
            if let path = challenge.dishImagePath, !path.isEmpty {
                dishImage = await ChallengeService.shared.loadImage(path: path)
            }
        }
    }

    private var timeRemainingPill: some View {
        let remaining = timeRemaining
        return HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10))
            Text(remaining)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Theme.darkTextTertiary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.darkSurface))
    }

    private var timeRemaining: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let endsAt = formatter.date(from: challenge.endsAt) else { return "—" }

        let interval = endsAt.timeIntervalSince(Date())
        if interval <= 0 { return "Ended" }

        let days = Int(interval / 86400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86400) / 3600)

        if days > 0 { return "\(days)d \(hours)h left" }
        if hours > 0 { return "\(hours)h left" }
        return "< 1h left"
    }
}
