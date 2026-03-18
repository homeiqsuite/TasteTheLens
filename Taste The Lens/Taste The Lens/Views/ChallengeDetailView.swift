import SwiftUI
import PhotosUI
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "ChallengeDetail")

struct ChallengeDetailView: View {
    let challenge: ChallengeDTO

    @State private var submissions: [ChallengeSubmissionDTO] = []
    @State private var dishImage: UIImage?
    @State private var isLoading = true
    @State private var showSubmitSheet = false
    @State private var showAuthPrompt = false
    @State private var upvotedIds: Set<String> = []

    private let challengeService = ChallengeService.shared
    private let authManager = AuthManager.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    challengeInfoSection
                    acceptButton
                    submissionsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.darkBg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showSubmitSheet) {
            ChallengeSubmitView(challenge: challenge) {
                Task {
                    submissions = try await challengeService.fetchSubmissions(challengeId: challenge.id)
                }
            }
        }
        .sheet(isPresented: $showAuthPrompt) {
            AuthPromptSheet()
        }
        .task {
            async let loadImage: Void = loadDishImage()
            async let loadSubs: Void = loadSubmissions()
            _ = await (loadImage, loadSubs)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        Color.clear
            .frame(height: 240)
            .overlay {
                if let image = dishImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Theme.darkSurface)
                        .overlay {
                            if isLoading {
                                ProgressView().tint(Theme.gold)
                            } else {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Theme.darkTextHint)
                            }
                        }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Challenge Info

    private var challengeInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(challenge.title)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(Theme.gold)

            if let desc = challenge.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .lineSpacing(4)
            }

            HStack(spacing: 16) {
                Label(timeRemaining, systemImage: "clock")
                Label("\(submissions.count) submissions", systemImage: "person.2")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.darkTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Accept Button

    private var acceptButton: some View {
        Button {
            HapticManager.medium()
            if authManager.isAuthenticated {
                showSubmitSheet = true
            } else {
                showAuthPrompt = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                Text("Accept Challenge")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(Theme.darkBg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.gold)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Submissions

    private var submissionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Submissions")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.darkTextPrimary)

            if submissions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.darkTextHint)
                    Text("No submissions yet — be the first!")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.darkTextHint)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(submissions) { submission in
                        submissionCard(submission)
                    }
                }
            }
        }
    }

    private func submissionCard(_ submission: ChallengeSubmissionDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Photo
            Color.clear
                .frame(height: 140)
                .overlay {
                    AsyncImage(url: URL(string: submission.photoUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Rectangle()
                                .fill(Theme.darkSurface)
                                .overlay {
                                    ProgressView().tint(Theme.gold)
                                }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // Caption
            if let caption = submission.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .lineLimit(2)
            }

            // Upvote
            Button {
                Task { await toggleUpvote(submission) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: upvotedIds.contains(submission.id) ? "arrow.up.circle.fill" : "arrow.up.circle")
                        .font(.system(size: 14))
                    Text("\(submission.upvoteCount)")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(upvotedIds.contains(submission.id) ? Theme.gold : Theme.darkTextTertiary)
            }
            .disabled(!authManager.isAuthenticated)
        }
        .glassCard(cornerRadius: 14)
        .task {
            if authManager.isAuthenticated {
                let voted = await challengeService.hasUpvoted(submissionId: submission.id)
                if voted { upvotedIds.insert(submission.id) }
            }
        }
    }

    // MARK: - Helpers

    private var timeRemaining: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let endsAtString = challenge.endsAt,
              let endsAt = formatter.date(from: endsAtString) else { return "—" }

        let interval = endsAt.timeIntervalSince(Date())
        if interval <= 0 { return "Ended" }

        let days = Int(interval / 86400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86400) / 3600)
        if days > 0 { return "\(days)d \(hours)h left" }
        if hours > 0 { return "\(hours)h left" }
        return "< 1h left"
    }

    private func loadDishImage() async {
        if let path = challenge.dishImagePath, !path.isEmpty {
            dishImage = await challengeService.loadImage(path: path)
        }
        isLoading = false
    }

    private func loadSubmissions() async {
        do {
            submissions = try await challengeService.fetchSubmissions(challengeId: challenge.id)
        } catch {
            logger.error("Failed to load submissions: \(error)")
        }
    }

    private func toggleUpvote(_ submission: ChallengeSubmissionDTO) async {
        guard authManager.isAuthenticated else { return }

        do {
            if upvotedIds.contains(submission.id) {
                try await challengeService.removeUpvote(submissionId: submission.id)
                upvotedIds.remove(submission.id)
            } else {
                try await challengeService.upvote(submissionId: submission.id)
                upvotedIds.insert(submission.id)
            }
            // Refresh submissions to get updated counts
            submissions = try await challengeService.fetchSubmissions(challengeId: challenge.id)
        } catch {
            logger.error("Upvote toggle failed: \(error)")
        }
    }
}
