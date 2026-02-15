import XCTest
@testable import SportApp

final class MatchStatsAggregatorTests: XCTestCase {
    func testAggregateCountsGoalAssistCardsAndSaves() {
        let teamA = UUID()
        let teamB = UUID()

        let p1 = Participant(id: UUID(), name: "Player One", teamId: teamA, elo: 1500)
        let p2 = Participant(id: UUID(), name: "Player Two", teamId: teamA, elo: 1480)
        let p3 = Participant(id: UUID(), name: "Player Three", teamId: teamB, elo: 1520)

        let events: [MatchEvent] = [
            MatchEvent(id: UUID(), type: .goal, minute: 5, playerId: p1.id, createdById: p1.id, createdAt: Date()),
            MatchEvent(id: UUID(), type: .assist, minute: 5, playerId: p2.id, createdById: p1.id, createdAt: Date()),
            MatchEvent(id: UUID(), type: .save, minute: 12, playerId: p3.id, createdById: p2.id, createdAt: Date()),
            MatchEvent(id: UUID(), type: .yellow, minute: 16, playerId: p2.id, createdById: p1.id, createdAt: Date()),
            MatchEvent(id: UUID(), type: .red, minute: 21, playerId: p3.id, createdById: p3.id, createdAt: Date()),
            MatchEvent(id: UUID(), type: .goal, minute: 38, playerId: p1.id, createdById: p2.id, createdAt: Date())
        ]

        let stats = MatchStatsAggregator.aggregate(participants: [p1, p2, p3], events: events)

        XCTAssertEqual(stats[p1.id]?.goals, 2)
        XCTAssertEqual(stats[p1.id]?.assists, 0)
        XCTAssertEqual(stats[p2.id]?.assists, 1)
        XCTAssertEqual(stats[p2.id]?.yellowCards, 1)
        XCTAssertEqual(stats[p3.id]?.saves, 1)
        XCTAssertEqual(stats[p3.id]?.redCards, 1)
    }

    func testSummaryRowsIncludesParticipantsWithoutEvents() {
        let teamID = UUID()
        let p1 = Participant(id: UUID(), name: "A", teamId: teamID, elo: 1400)
        let p2 = Participant(id: UUID(), name: "B", teamId: teamID, elo: 1450)

        let rows = MatchStatsAggregator.summaryRows(
            participants: [p1, p2],
            events: [
                MatchEvent(id: UUID(), type: .goal, minute: 2, playerId: p1.id, createdById: p1.id, createdAt: Date())
            ]
        )

        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first(where: { $0.participant.id == p1.id })?.stats.goals, 1)
        XCTAssertEqual(rows.first(where: { $0.participant.id == p2.id })?.stats.goals, 0)
    }
}
