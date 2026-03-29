import SwiftUI
import PhotosUI
import Auth
import os

private let logger = makeLogger(category: "ChallengeDetail")

struct ChallengeDetailView: View {
    let challenge: ChallengeDTO

    @State private var submissions: [ChallengeSubmissionDTO] = []
    @State private var dishImage: UIImage?
    @State private var isLoading = true
    @State private var showSubmitSheet = false
    @State private var showAuthPrompt = false
    @State private var hasSubmitted = false
    @State private var upvotedIds: Set<String> = []

    // Winner management
    @State private var localWinnerSubmissionId: String?
    @State private var isCreator = false
    @State private var selectedWinnerId: String?
    @State private var showDeclareWinnerConfirmation = false
    @State private var isDeclaring = false

    private let challengeService = ChallengeService.shared
    private let authManager = AuthManager.shared

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var challengeIsEnded: Bool {
        challenge.isEnded || localWinnerSubmissionId != nil
    }

    var body: some View {
        ZStack {
            Theme.darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    heroSection
                    challengeInfoSection
                    actionButton
                    submissionsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .refreshable {
                await loadSubmissions()
                await checkIfSubmitted()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.darkBg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showSubmitSheet) {
            ChallengeSubmitView(challenge: challenge) {
                hasSubmitted = true
                Task {
                    submissions = try await challengeService.fetchSubmissions(challengeId: challenge.id)
                }
            }
        }
        .sheet(isPresented: $showAuthPrompt) {
            AuthPromptSheet()
        }
        .alert("Declare Winner?", isPresented: $showDeclareWinnerConfirmation) {
            Button("Declare Winner", role: .destructive) {
                Task { await declareWinner() }
            }
            Button("Cancel", role: .cancel) {
                selectedWinnerId = nil
            }
        } message: {
            Text("This cannot be undone. The challenge will be marked as completed.")
        }
        .task {
            localWinnerSubmissionId = challenge.winnerSubmissionId
            isCreator = authManager.currentUser?.id.uuidString.lowercased() == challenge.creatorId
            async let loadImage: Void = loadDishImage()
            async let loadSubs: Void = loadSubmissions()
            async let checkSubmitted: Void = checkIfSubmitted()
            _ = await (loadImage, loadSubs, checkSubmitted)
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
                if localWinnerSubmissionId != nil {
                    Label("Winner declared", systemImage: "trophy.fill")
                        .foregroundStyle(Theme.gold)
                } else {
                    Label(timeRemaining, systemImage: "clock")
                }
                Label("\(submissions.count) submissions", systemImage: "person.2")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.darkTextTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        if challengeIsEnded {
            // Challenge ended — show disabled state
            HStack(spacing: 8) {
                Image(systemName: localWinnerSubmissionId != nil ? "trophy.fill" : "clock.badge.checkmark")
                Text(localWinnerSubmissionId != nil ? "Challenge Complete" : "Challenge Ended")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(Theme.darkTextTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.darkSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            // Active challenge — accept button
            Button {
                HapticManager.medium()
                if authManager.isAuthenticated {
                    showSubmitSheet = true
                } else {
                    showAuthPrompt = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasSubmitted ? "checkmark.circle.fill" : "flame.fill")
                    Text(hasSubmitted ? "Submitted" : "Accept Challenge")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(hasSubmitted ? Theme.darkTextTertiary : Theme.darkBg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(hasSubmitted ? Theme.darkSurface : Theme.gold)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(hasSubmitted)
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
        let isWinner = submission.id == localWinnerSubmissionId

        return VStack(alignment: .leading, spacing: 8) {
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
                .overlay(alignment: .topTrailing) {
                    if isWinner {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.gold)
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .padding(6)
                    }
                }

            // Winner label
            if isWinner {
                Text("Winner")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.gold)
            }

            // Display name
            if let name = submission.displayName, !name.isEmpty {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isWinner ? Theme.gold : Theme.darkTextSecondary)
                    .lineLimit(1)
            }

            // Caption
            if let caption = submission.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.darkTextSecondary)
                    .lineLimit(2)
            }

            // Upvote + Crown
            HStack {
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

                Spacer()

                // Crown button for creator to declare winner (only after ended, not on own submissions)
                if isCreator && challenge.isEnded && localWinnerSubmissionId == nil
                    && submission.userId != authManager.currentUser?.id.uuidString.lowercased() {
                    Button {
                        selectedWinnerId = submission.id
                        showDeclareWinnerConfirmation = true
                    } label: {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.gold.opacity(0.7))
                    }
                }
            }
        }
        .glassCard(cornerRadius: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isWinner ? Theme.gold : .clear, lineWidth: 2)
        )
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

    private func checkIfSubmitted() async {
        if authManager.isAuthenticated {
            hasSubmitted = await challengeService.hasSubmitted(challengeId: challenge.id)
        }
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
            submissions = try await challengeService.fetchSubmissions(challengeId: challenge.id)
        } catch {
            logger.error("Upvote toggle failed: \(error)")
        }
    }

    private func declareWinner() async {
        guard let submissionId = selectedWinnerId else { return }
        isDeclaring = true
        defer { isDeclaring = false }

        do {
            try await challengeService.declareWinner(
                challengeId: challenge.id,
                submissionId: submissionId,
                challengeTitle: challenge.title
            )
            localWinnerSubmissionId = submissionId
            HapticManager.success()
        } catch {
            logger.error("Failed to declare winner: \(error)")
        }
    }
}
