import Foundation

actor SupabasePlayerProfileRepository: PlayerProfileRepository {
    private let dataService: SupabaseDataService
    private let email: String?

    init(dataService: SupabaseDataService, email: String?) {
        self.dataService = dataService
        self.email = email
    }

    func fetchPlayer(id: UUID) async throws -> Player {
        try await dataService.fetchPlayer(id: id)
    }

    func updatePlayer(_ player: Player) async throws -> Player {
        try await dataService.saveProfile(player, email: email)
        return try await dataService.fetchPlayer(id: player.id)
    }

    func fetchMatchHistory(playerID: UUID) async throws -> [PlayerMatch] {
        try await dataService.fetchMatchHistory(playerID: playerID)
    }
}
