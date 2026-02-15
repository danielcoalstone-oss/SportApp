import Foundation

protocol PlayerProfileRepository {
    func fetchPlayer(id: UUID) async throws -> Player
    func updatePlayer(_ player: Player) async throws -> Player
    func fetchMatchHistory(playerID: UUID) async throws -> [PlayerMatch]
}

enum PlayerProfileRepositoryError: LocalizedError {
    case playerNotFound

    var errorDescription: String? {
        switch self {
        case .playerNotFound:
            return "Player profile was not found."
        }
    }
}

actor MockPlayerProfileRepository: PlayerProfileRepository {
    private var playersByID: [UUID: Player]
    private var matchesByPlayerID: [UUID: [PlayerMatch]]

    init(seedPlayer: Player, seedMatches: [PlayerMatch]? = nil) {
        self.playersByID = [seedPlayer.id: seedPlayer]
        self.matchesByPlayerID = [seedPlayer.id: seedMatches ?? Self.makeMockMatches()]
    }

    static func makeMockMatches() -> [PlayerMatch] {
        let now = Date()
        return [
            PlayerMatch(
                id: UUID(),
                date: Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now,
                opponent: "River City United",
                result: "Upcoming",
                score: "TBD",
                ratingDelta: 0,
                isCompleted: false,
                outcome: nil
            ),
            PlayerMatch(
                id: UUID(),
                date: Calendar.current.date(byAdding: .hour, value: 20, to: now) ?? now,
                opponent: "Eastside Ballers",
                result: "Upcoming",
                score: "TBD",
                ratingDelta: 0,
                isCompleted: false,
                outcome: nil
            ),
            PlayerMatch(
                id: UUID(),
                date: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now,
                opponent: "Street Falcons",
                result: "Win",
                score: "6-4",
                ratingDelta: 13,
                isCompleted: true,
                outcome: .win
            ),
            PlayerMatch(
                id: UUID(),
                date: Calendar.current.date(byAdding: .day, value: -6, to: now) ?? now,
                opponent: "South Side FC",
                result: "Loss",
                score: "3-5",
                ratingDelta: -9,
                isCompleted: true,
                outcome: .loss
            ),
            PlayerMatch(
                id: UUID(),
                date: Calendar.current.date(byAdding: .day, value: -9, to: now) ?? now,
                opponent: "North Strikers",
                result: "Draw",
                score: "2-2",
                ratingDelta: 0,
                isCompleted: true,
                outcome: .draw
            )
        ]
    }

    func fetchPlayer(id: UUID) async throws -> Player {
        try await Task.sleep(nanoseconds: 220_000_000)
        guard let player = playersByID[id] else {
            throw PlayerProfileRepositoryError.playerNotFound
        }
        return player
    }

    func updatePlayer(_ player: Player) async throws -> Player {
        try await Task.sleep(nanoseconds: 220_000_000)
        playersByID[player.id] = player
        return player
    }

    func fetchMatchHistory(playerID: UUID) async throws -> [PlayerMatch] {
        try await Task.sleep(nanoseconds: 220_000_000)
        return matchesByPlayerID[playerID] ?? []
    }
}
