import SwiftUI

struct TournamentsView: View {
    private enum PlayFilter {
        case gamesAndTournaments
        case practices
    }

    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var selectedFilter: PlayFilter = .gamesAndTournaments

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    filterButton(
                        title: "Games/Tournaments",
                        isSelected: selectedFilter == .gamesAndTournaments
                    ) {
                        selectedFilter = .gamesAndTournaments
                    }

                    filterButton(
                        title: "Practices",
                        isSelected: selectedFilter == .practices
                    ) {
                        selectedFilter = .practices
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)

                if selectedFilter == .gamesAndTournaments {
                    List {
                        if !appViewModel.upcomingCreatedGames.isEmpty {
                            Section("Created Games") {
                                ForEach(appViewModel.upcomingCreatedGames) { game in
                                    NavigationLink {
                                        GameDetailView(game: game)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(game.locationName)
                                                    .font(.headline)
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
                                    }
                                }
                            }
                        }

                        if !appViewModel.pastCreatedGames.isEmpty {
                            Section("Past Matches") {
                                ForEach(appViewModel.pastCreatedGames) { game in
                                    NavigationLink {
                                        GameDetailView(game: game)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(game.locationName)
                                                    .font(.headline)
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
                                    }
                                }
                            }
                        }

                        Section("Tournaments") {
                            ForEach(appViewModel.visibleTournaments) { tournament in
                                NavigationLink {
                                    TournamentDetailView(tournamentID: tournament.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(tournament.title)
                                            .font(.headline)
                                        Text(DateFormatterService.tournamentDateTime.string(from: tournament.startDate))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("Open team slots: \(tournament.openSpots)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    List(appViewModel.visiblePractices) { practice in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(practice.title)
                                    .font(.headline)
                                Spacer()
                                Text(practice.isOpenJoin ? "Open Join" : "Approval Needed")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(DateFormatterService.tournamentDateTime.string(from: practice.startDate))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(practice.location) • Players: \(practice.numberOfPlayers)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Elo: \(practice.minElo)-\(practice.maxElo)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Play")
        }
    }

    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
        )
    }
}

struct GameDetailView: View {
    let game: CreatedGame

    private var openSlots: Int {
        max(game.numberOfPlayers - game.players.count, 0)
    }

    private var addressText: String {
        if game.address.isEmpty {
            return game.locationName
        }
        return "\(game.locationName), \(game.address)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(DateFormatterService.tournamentDateTime.string(from: game.scheduledDate), systemImage: "clock.fill")
                    Label(addressText, systemImage: "mappin.and.ellipse")
                    Label("Duration: \(game.durationMinutes) min • \(game.format.rawValue)", systemImage: "timer")
                    Label(game.hasCourtBooked ? "Field booked" : "Field not booked", systemImage: "sportscourt.fill")
                    Label(game.isRatingGame ? "Rating game" : "Not rating game", systemImage: "chart.bar.fill")
                    Label("Average Elo: \(game.averageElo)", systemImage: "gauge.with.dots.needle.67percent")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.95), Color.indigo.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Players: \(game.players.count)/\(game.numberOfPlayers)")
                        .font(.title3.bold())

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                        ForEach(game.players) { player in
                            PlayerSlotView(name: player.fullName, avatarImageData: player.avatarImageData, elo: player.eloRating)
                        }

                        ForEach(0..<openSlots, id: \.self) { _ in
                            EmptySlotView()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                NavigationLink {
                    MatchDetailsView(match: makeMatch())
                } label: {
                    HStack {
                        Text("Open Match Details")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .navigationTitle("Game")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeMatch() -> Match {
        let allPlayers = game.players
        let splitIndex = max(allPlayers.count / 2, 1)
        let homePlayers = Array(allPlayers.prefix(splitIndex))
        let awayPlayers = Array(allPlayers.dropFirst(splitIndex))

        let homeTeam = Team(
            id: UUID(),
            name: "Home Team",
            members: homePlayers,
            maxPlayers: max(game.numberOfPlayers / 2, 1)
        )

        let awayTeam = Team(
            id: UUID(),
            name: "Away Team",
            members: awayPlayers,
            maxPlayers: max(game.numberOfPlayers / 2, 1)
        )

        let participants = homePlayers.map {
            Participant(
                id: $0.id,
                name: $0.fullName,
                teamId: homeTeam.id,
                elo: $0.eloRating,
                positionGroup: positionGroup(for: $0)
            )
        } + awayPlayers.map {
            Participant(
                id: $0.id,
                name: $0.fullName,
                teamId: awayTeam.id,
                elo: $0.eloRating,
                positionGroup: positionGroup(for: $0)
            )
        }

        let seedEvents: [MatchEvent]
        let ownerId = game.ownerId
        if let first = participants.first {
            seedEvents = [
                MatchEvent(
                    id: UUID(),
                    type: .goal,
                    minute: 8,
                    playerId: first.id,
                    createdById: first.id,
                    createdAt: Date()
                )
            ]
        } else {
            seedEvents = []
        }

        return Match(
            id: game.id,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            participants: participants,
            events: seedEvents,
            location: addressText,
            startTime: game.scheduledDate,
            format: game.format.rawValue,
            notes: game.notes,
            isRatingGame: game.isRatingGame,
            isFieldBooked: game.hasCourtBooked,
            maxPlayers: game.numberOfPlayers,
            ownerId: ownerId,
            organiserIds: [ownerId]
        )
    }

    private func positionGroup(for user: User) -> PositionGroup {
        guard let raw = user.preferredPositions.first?.rawValue.uppercased() else { return .bench }
        switch raw {
        case "GK":
            return .gk
        case "CB", "LB", "RB", "LWB", "RWB":
            return .defenders
        case "DM", "CM", "AM", "LM", "RM":
            return .midfielders
        case "LW", "RW", "ST", "CF", "SS":
            return .forwards
        default:
            return .bench
        }
    }
}

private struct PlayerSlotView: View {
    let name: String
    let avatarImageData: Data?
    let elo: Int

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                PlayerAvatarView(name: name, imageData: avatarImageData, size: 58)

                Text("\(elo)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
                    .offset(x: 8, y: -6)
            }

            Text(name.components(separatedBy: " ").first ?? name)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

private struct EmptySlotView: View {
    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundStyle(.secondary)
                .frame(width: 58, height: 58)
                .overlay(
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                )

            Text("Invite")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
