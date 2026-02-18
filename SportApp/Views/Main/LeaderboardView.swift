import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List(Array(appViewModel.leaderboard.enumerated()), id: \.element.id) { index, player in
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

                    Text("\(player.eloRating)")
                        .font(.title3.bold())
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Рейтинг Elo")
        }
    }
}
