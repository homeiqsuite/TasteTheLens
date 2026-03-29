import SwiftUI
import os

private let logger = makeLogger(category: "ChallengeFeed")

struct ChallengeFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: ChallengeFilter = .trending
    @State private var pastChallengesOffset = 0

    private let challengeService = ChallengeService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    filterTabs

                    if challengeService.isLoading && challengeService.challenges.isEmpty {
                        Spacer()
                        ProgressView()
                            .tint(Theme.gold)
                        Spacer()
                    } else if challengeService.challenges.isEmpty {
                        ScrollView {
                            emptyState
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(challengeService.challenges) { challenge in
                                    NavigationLink(value: challenge.id) {
                                        ChallengeCardView(challenge: challenge)
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Load More button for past challenges
                                if selectedFilter == .past && challengeService.hasMorePastChallenges {
                                    Button {
                                        pastChallengesOffset += 20
                                        Task {
                                            try? await challengeService.fetchChallenges(filter: .past, offset: pastChallengesOffset)
                                        }
                                    } label: {
                                        Text("Load More")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Theme.gold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                        }
                        .refreshable {
                            pastChallengesOffset = 0
                            try? await challengeService.fetchChallenges(filter: selectedFilter)
                        }
                    }
                }
            }
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.darkBg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
            .navigationDestination(for: String.self) { challengeId in
                if let challenge = challengeService.challenges.first(where: { $0.id == challengeId }) {
                    ChallengeDetailView(challenge: challenge)
                }
            }
            .task {
                try? await challengeService.fetchChallenges(filter: selectedFilter)
            }
            .onChange(of: selectedFilter) { _, newFilter in
                pastChallengesOffset = 0
                Task {
                    try? await challengeService.fetchChallenges(filter: newFilter)
                }
            }
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ChallengeFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.displayName)
                            .font(.system(size: 14, weight: selectedFilter == filter ? .bold : .medium))
                            .foregroundStyle(selectedFilter == filter ? Theme.darkBg : Theme.darkTextSecondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selectedFilter == filter ? Theme.gold : Theme.darkSurface)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 48))
                .foregroundStyle(Theme.darkTextHint)
            Text("No challenges yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.darkTextTertiary)
            Text("Generate a recipe and be the first to throw the gauntlet!")
                .font(.system(size: 14))
                .foregroundStyle(Theme.darkTextHint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}
