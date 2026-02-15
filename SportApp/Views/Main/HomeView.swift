import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let user = appViewModel.currentUser {
                        Text("Hi, \(user.fullName)")
                            .font(.title2.bold())

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Current Elo: \(user.eloRating)", systemImage: "chart.line.uptrend.xyaxis")
                            Label("Matches: \(user.matchesPlayed)", systemImage: "figure.soccer")
                            Label("Win rate: \(Int(user.winRate * 100))%", systemImage: "trophy")
                        }
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    Text("Quick Booking")
                        .font(.headline)

                    ForEach(appViewModel.visibleTournaments.prefix(3)) { tournament in
                        NavigationLink {
                            TournamentDetailView(tournamentID: tournament.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(tournament.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(DateFormatterService.tournamentDateTime.string(from: tournament.startDate))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(tournament.location) - $\(Int(tournament.entryFee))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if !appViewModel.upcomingCreatedGames.isEmpty {
                        Text("Upcoming Matches")
                            .font(.headline)

                        ForEach(appViewModel.upcomingCreatedGames.prefix(3)) { game in
                            NavigationLink {
                                GameDetailView(game: game)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(game.locationName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text(game.isPrivateGame ? "Private" : "Public")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(DateFormatterService.tournamentDateTime.string(from: game.scheduledDate))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("Players: \(game.players.count)/\(game.numberOfPlayers) • Avg Elo: \(game.averageElo)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    if !appViewModel.pastCreatedGames.isEmpty {
                        Text("Past Matches")
                            .font(.headline)

                        ForEach(appViewModel.pastCreatedGames.prefix(3)) { game in
                            NavigationLink {
                                GameDetailView(game: game)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(game.locationName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text("Past")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(DateFormatterService.tournamentDateTime.string(from: game.scheduledDate))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("Players: \(game.players.count)/\(game.numberOfPlayers) • Avg Elo: \(game.averageElo)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    Button("Simulate Win (+ Elo)") {
                        appViewModel.simulateMatchResult(didWin: true, opponentAverageElo: 1500)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Simulate Loss (- Elo)") {
                        appViewModel.simulateMatchResult(didWin: false, opponentAverageElo: 1500)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Main")
        }
    }
}
