import XCTest
@testable import SportApp

final class TournamentStandingsServiceTests: XCTestCase {
    func testStandingsSortAndStats() {
        let teamA = Team(id: UUID(), name: "Alpha", members: [], maxPlayers: 6)
        let teamB = Team(id: UUID(), name: "Bravo", members: [], maxPlayers: 6)
        let teamC = Team(id: UUID(), name: "Charlie", members: [], maxPlayers: 6)

        let tournament = Tournament(
            id: UUID(),
            title: "League",
            location: "Arena",
            startDate: Date(),
            teams: [teamA, teamB, teamC],
            entryFee: 0,
            maxTeams: 8,
            format: "5v5",
            ownerId: UUID(),
            organiserIds: [],
            matches: [
                TournamentMatch(homeTeamId: teamA.id, awayTeamId: teamB.id, startTime: Date(), homeScore: 2, awayScore: 0, status: .completed),
                TournamentMatch(homeTeamId: teamA.id, awayTeamId: teamC.id, startTime: Date(), homeScore: 1, awayScore: 1, status: .completed),
                TournamentMatch(homeTeamId: teamB.id, awayTeamId: teamC.id, startTime: Date(), homeScore: nil, awayScore: nil, status: .scheduled),
                TournamentMatch(homeTeamId: teamB.id, awayTeamId: teamC.id, startTime: Date(), homeScore: 4, awayScore: 4, status: .cancelled)
            ],
            disputeStatus: .none
        )

        let rows = TournamentStandingsService.standings(for: tournament)
        XCTAssertEqual(rows.count, 3)

        XCTAssertEqual(rows[0].teamName, "Alpha")
        XCTAssertEqual(rows[0].points, 4)
        XCTAssertEqual(rows[0].played, 2)
        XCTAssertEqual(rows[0].goalsFor, 3)
        XCTAssertEqual(rows[0].goalsAgainst, 1)

        XCTAssertEqual(rows[1].teamName, "Charlie")
        XCTAssertEqual(rows[1].points, 1)

        XCTAssertEqual(rows[2].teamName, "Bravo")
        XCTAssertEqual(rows[2].points, 0)
    }

    func testTieBreakerFallsBackToName() {
        let teamA = Team(id: UUID(), name: "Ajax", members: [], maxPlayers: 6)
        let teamB = Team(id: UUID(), name: "Boca", members: [], maxPlayers: 6)

        let tournament = Tournament(
            id: UUID(),
            title: "Cup",
            location: "Arena",
            startDate: Date(),
            teams: [teamA, teamB],
            entryFee: 0,
            maxTeams: 8,
            format: "5v5",
            ownerId: UUID(),
            organiserIds: [],
            matches: [],
            disputeStatus: .none
        )

        let rows = TournamentStandingsService.standings(for: tournament)
        XCTAssertEqual(rows.map(\.teamName), ["Ajax", "Boca"])
    }
}
