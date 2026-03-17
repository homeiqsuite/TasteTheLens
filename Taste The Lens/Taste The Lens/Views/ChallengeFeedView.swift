import SwiftUI
import os

private let logger = Logger(subsystem: "com.eightgates.TasteTheLens", category: "ChallengeFeed")

struct ChallengeFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: ChallengeFilter = .trending

    private let challengeService = ChallengeService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.darkBg.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(ChallengeFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

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
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                        }
                        .refreshable {
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
                Task {
                    try? await challengeService.fetchChallenges(filter: newFilter)
                }
            }
        }
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
