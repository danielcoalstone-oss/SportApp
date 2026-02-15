import XCTest
@testable import SportApp

final class MatchRSVPServiceTests: XCTestCase {
    func testGoingWhenFullMovesUserToWaitlist() {
        let teamId = UUID()
        let userA = Participant(id: UUID(), name: "A", teamId: teamId, elo: 1400, rsvpStatus: .going)
        let userB = Participant(id: UUID(), name: "B", teamId: teamId, elo: 1450, rsvpStatus: .invited)

        var participants = [userA, userB]

        let result = MatchRSVPService.updateRSVP(
            participants: &participants,
            userId: userB.id,
            desiredStatus: .going,
            maxPlayers: 1,
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(result.effectiveStatus, .waitlisted)
        XCTAssertEqual(participants.first(where: { $0.id == userB.id })?.rsvpStatus, .waitlisted)
        XCTAssertEqual(result.message, "Match is full. You were added to the waitlist.")
    }

    func testDeclinePromotesOldestWaitlistedPlayer() {
        let now = Date(timeIntervalSince1970: 1000)
        let teamId = UUID()

        let going = Participant(id: UUID(), name: "Going", teamId: teamId, elo: 1500, rsvpStatus: .going)
        let declines = Participant(id: UUID(), name: "Decliner", teamId: teamId, elo: 1480, rsvpStatus: .going)
        let waitlistedOlder = Participant(
            id: UUID(),
            name: "Old Waitlist",
            teamId: teamId,
            elo: 1420,
            rsvpStatus: .waitlisted,
            invitedAt: now,
            waitlistedAt: Date(timeIntervalSince1970: 500)
        )
        let waitlistedNewer = Participant(
            id: UUID(),
            name: "New Waitlist",
            teamId: teamId,
            elo: 1430,
            rsvpStatus: .waitlisted,
            invitedAt: now,
            waitlistedAt: Date(timeIntervalSince1970: 700)
        )

        var participants = [going, declines, waitlistedOlder, waitlistedNewer]

        let result = MatchRSVPService.updateRSVP(
            participants: &participants,
            userId: declines.id,
            desiredStatus: .declined,
            maxPlayers: 2,
            now: now
        )

        XCTAssertEqual(participants.first(where: { $0.id == declines.id })?.rsvpStatus, .declined)
        XCTAssertEqual(participants.first(where: { $0.id == waitlistedOlder.id })?.rsvpStatus, .going)
        XCTAssertEqual(participants.first(where: { $0.id == waitlistedNewer.id })?.rsvpStatus, .waitlisted)
        XCTAssertEqual(result.promotedParticipantName, "Old Waitlist")
    }
}
