import SwiftUI

struct LeaderboardView: View {
    private enum LeaderboardTab: String, CaseIterable, Identifiable {
        case players = "Players"
        case coaches = "Coaches"

        var id: String { rawValue }
    }

    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var selectedTab: LeaderboardTab = .players

    private var filteredLeaderboard: [User] {
        switch selectedTab {
        case .players:
            return appViewModel.leaderboard.filter { !$0.isCoachActive }
        case .coaches:
            return appViewModel.users
                .filter { $0.isCoachActive }
                .sorted { lhs, rhs in
                    let lhsReviews = appViewModel.reviews(for: lhs.id).count
                    let rhsReviews = appViewModel.reviews(for: rhs.id).count
                    if lhsReviews != rhsReviews { return lhsReviews > rhsReviews }
                    if lhs.eloRating != rhs.eloRating { return lhs.eloRating > rhs.eloRating }
                    return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
                }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Leaderboard", selection: $selectedTab) {
                    ForEach(LeaderboardTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                List {
                    if filteredLeaderboard.isEmpty {
                        Text(selectedTab == .players ? "No players yet." : "No coaches yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(filteredLeaderboard.enumerated()), id: \.element.id) { index, player in
                            NavigationLink {
                                PublicProfileView(userID: player.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Text("#\(index + 1)")
                                        .font(.headline)
                                        .foregroundStyle(index < 3 ? .orange : .secondary)
                                        .frame(width: 36, alignment: .leading)

                                    PlayerAvatarView(
                                        name: player.fullName,
                                        imageData: player.avatarImageData,
                                        size: 34
                                    )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(player.fullName)
                                            .font(.headline)
                                        Text("\(player.city) - \(player.preferredPositionsSummary)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if selectedTab == .coaches {
                                        let coachReviews = appViewModel.reviews(for: player.id)
                                        let averageRating = coachReviews.isEmpty
                                            ? 0
                                            : Double(coachReviews.map(\.rating).reduce(0, +)) / Double(coachReviews.count)
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(String(format: "%.1f / 5", averageRating))
                                                .font(.caption.bold())
                                                .foregroundStyle(.secondary)
                                            Text("\(coachReviews.count) reviews")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("\(player.eloRating)")
                                            .font(.title3.bold())
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .appListBackground()
            }
            .navigationTitle("Elo Leaderboard")
        }
    }
}
