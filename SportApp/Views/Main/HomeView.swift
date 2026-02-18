import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let user = appViewModel.currentUser {
                        Text("Привет, \(user.fullName)")
                            .font(.title2.bold())

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Текущий Elo: \(user.eloRating)", systemImage: "chart.line.uptrend.xyaxis")
                            Label("Матчи: \(user.matchesPlayed)", systemImage: "figure.soccer")
                            Label("Процент побед: \(Int(user.winRate * 100))%", systemImage: "trophy")
                        }
                        .font(.subheadline)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    Text("Быстрая запись")
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
                        Text("Ближайшие матчи")
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
                                        Text(game.isPrivateGame ? "Приватный" : "Публичный")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(DateFormatterService.tournamentDateTime.string(from: game.scheduledDate))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("Игроки: \(game.players.count)/\(game.numberOfPlayers) • Ср. Elo: \(game.averageElo)")
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
                        Text("Прошедшие матчи")
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
                                        Text("Прошедший")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(DateFormatterService.tournamentDateTime.string(from: game.scheduledDate))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("Игроки: \(game.players.count)/\(game.numberOfPlayers) • Ср. Elo: \(game.averageElo)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    Button("Симулировать победу (+ Elo)") {
                        appViewModel.simulateMatchResult(didWin: true, opponentAverageElo: 1500)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Симулировать поражение (- Elo)") {
                        appViewModel.simulateMatchResult(didWin: false, opponentAverageElo: 1500)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Главная")
        }
    }
}
