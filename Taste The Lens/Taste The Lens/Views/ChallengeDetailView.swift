import SwiftUI
import SwiftData
import PhotosUI
import Auth
import os

private let logger = makeLogger(category: "ChallengeDetail")

struct ChallengeDetailView: View {
    let challenge: ChallengeDTO

    @Environment(\.modelContext) private var modelContext

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

    // Ratings
    @State private var myRatings: [String: Int] = [:]

    // Full-screen photo
    @State private var fullscreenPhotoURL: String?

    // Save recipe
    @State private var isSavingRecipe = false
    @State private var recipeSaved = false

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
        .fullScreenCover(item: Binding(
            get: { fullscreenPhotoURL.map { FullscreenURL(url: $0) } },
            set: { fullscreenPhotoURL = $0?.url }
        )) { item in
            FullscreenPhotoView(url: item.url)
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
            checkIfRecipeSaved()
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

            if let keywords = challenge.keywords, !keywords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(keywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.darkTextSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Theme.darkSurface))
                        }
                    }
                }
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

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButton: some View {
        if challengeIsEnded {
            // Challenge ended — show status + save option
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: localWinnerSubmissionId != nil ? "trophy.fill" : "clock.badge.checkmark")
                    Text(localWinnerSubmissionId != nil ? "Complete" : "Ended")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Theme.darkTextTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.darkSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                saveRecipeButton
            }
        } else {
            // Active challenge — accept + save
            HStack(spacing: 12) {
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
                        Text(hasSubmitted ? "Submitted" : "Accept")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(hasSubmitted ? Theme.darkTextTertiary : Theme.darkBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(hasSubmitted ? Theme.darkSurface : Theme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(hasSubmitted)

                saveRecipeButton
            }
        }
    }

    private var saveRecipeButton: some View {
        Button {
            HapticManager.medium()
            Task { await saveRecipe() }
        } label: {
            HStack(spacing: 8) {
                if isSavingRecipe {
                    ProgressView()
                        .tint(Theme.darkBg)
                        .controlSize(.small)
                } else {
                    Image(systemName: recipeSaved ? "checkmark.circle.fill" : "bookmark.fill")
                }
                Text(recipeSaved ? "Saved" : "Save")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(recipeSaved ? Theme.darkTextTertiary : Theme.gold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(recipeSaved ? Theme.darkSurface : Theme.gold.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(recipeSaved ? .clear : Theme.gold.opacity(0.4), lineWidth: 1)
            )
        }
        .disabled(isSavingRecipe || recipeSaved)
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
                .onTapGesture {
                    fullscreenPhotoURL = submission.photoUrl
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

            // Star ratings
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            guard authManager.isAuthenticated else { return }
                            myRatings[submission.id] = star
                            Task {
                                try? await challengeService.rateSubmission(submissionId: submission.id, stars: star)
                                submissions = (try? await challengeService.fetchSubmissions(challengeId: challenge.id)) ?? submissions
                            }
                        } label: {
                            Image(systemName: star <= (myRatings[submission.id] ?? 0) ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundStyle(star <= (myRatings[submission.id] ?? 0) ? Theme.gold : Theme.darkTextHint)
                        }
                        .disabled(!authManager.isAuthenticated)
                    }
                }

                if let avg = submission.averageRating, let count = submission.ratingCount, count > 0 {
                    Text(String(format: "%.1f · %d rating%@", avg, count, count == 1 ? "" : "s"))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.darkTextHint)
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
                async let voted = challengeService.hasUpvoted(submissionId: submission.id)
                async let rating = challengeService.getUserRating(submissionId: submission.id)
                let (v, r) = await (voted, rating)
                if v { upvotedIds.insert(submission.id) }
                if let r { myRatings[submission.id] = r }
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

    private func checkIfRecipeSaved() {
        let recipeId = challenge.recipeId
        let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.remoteId == recipeId })
        recipeSaved = (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    private func saveRecipe() async {
        isSavingRecipe = true
        defer { isSavingRecipe = false }

        do {
            let recipe = try await challengeService.fetchChallengeRecipe(recipeId: challenge.recipeId)
            modelContext.insert(recipe)
            try modelContext.save()
            recipeSaved = true
            HapticManager.success()
            logger.info("Saved challenge recipe \(challenge.recipeId) locally")
        } catch {
            logger.error("Failed to save challenge recipe: \(error)")
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

// MARK: - Helpers

private struct FullscreenURL: Identifiable {
    let id = UUID()
    let url: String
}

private struct FullscreenPhotoView: View {
    let url: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, lastScale * value)
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1.0 {
                                        withAnimation(.spring()) { scale = 1.0 }
                                        lastScale = 1.0
                                    }
                                }
                        )
                default:
                    ProgressView().tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(16)
            }
        }
    }
}
