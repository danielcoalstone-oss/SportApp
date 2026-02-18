import XCTest
@testable import SportApp

final class AccessPolicyTests: XCTestCase {
    func testDefaultUserRoleIsPlayer() {
        let user = User(
            id: UUID(),
            fullName: "Default User",
            email: "default@example.com",
            favoritePosition: "Winger",
            city: "Austin",
            eloRating: 1400,
            matchesPlayed: 0,
            wins: 0
        )

        XCTAssertEqual(user.globalRole, .player)
        XCTAssertFalse(user.isAdmin)
    }

    func testAdminCanDoEverything() {
        let admin = makeUser(role: .admin)
        let match = makeMatch(ownerId: UUID())
        let tournament = makeTournament(ownerId: UUID())
        let coachSession = CoachSessionAccessTarget(ownerId: UUID(), organiserIds: [])

        XCTAssertTrue(AccessPolicy.canCreateMatch(admin))
        XCTAssertTrue(AccessPolicy.canEditMatch(admin, match))
        XCTAssertTrue(AccessPolicy.canInviteToMatch(admin, match))
        XCTAssertTrue(AccessPolicy.canEnterMatchResult(admin, match))
        XCTAssertTrue(AccessPolicy.canCreateTournament(admin))
        XCTAssertTrue(AccessPolicy.canEditTournament(admin, tournament))
        XCTAssertTrue(AccessPolicy.canManageTournamentTeams(admin, tournament))
        XCTAssertTrue(AccessPolicy.canCreateTournamentMatch(admin, tournament))
        XCTAssertTrue(AccessPolicy.canEnterTournamentResult(admin, tournament))
        XCTAssertTrue(AccessPolicy.canCreateCoachSession(admin))
        XCTAssertTrue(AccessPolicy.canEditCoachSession(admin, coachSession))
        XCTAssertTrue(AccessPolicy.canSearchPlayersAsCoach(admin))
        XCTAssertTrue(AccessPolicy.canManageUsersAsAdmin(admin))
    }

    func testOrganiserCanEditOnlyOwnedObjects() {
        let organiser = makeUser(role: .player)
        let ownedMatch = makeMatch(ownerId: organiser.id)
        let otherMatch = makeMatch(ownerId: UUID())
        let ownedTournament = makeTournament(ownerId: organiser.id)
        let otherTournament = makeTournament(ownerId: UUID())

        XCTAssertTrue(AccessPolicy.canEditMatch(organiser, ownedMatch))
        XCTAssertTrue(AccessPolicy.canInviteToMatch(organiser, ownedMatch))
        XCTAssertTrue(AccessPolicy.canEnterMatchResult(organiser, ownedMatch))
        XCTAssertFalse(AccessPolicy.canEditMatch(organiser, otherMatch))
        XCTAssertTrue(AccessPolicy.canEditTournament(organiser, ownedTournament))
        XCTAssertTrue(AccessPolicy.canManageTournamentTeams(organiser, ownedTournament))
        XCTAssertTrue(AccessPolicy.canCreateTournamentMatch(organiser, ownedTournament))
        XCTAssertTrue(AccessPolicy.canEnterTournamentResult(organiser, ownedTournament))
        XCTAssertFalse(AccessPolicy.canEditTournament(organiser, otherTournament))
        XCTAssertFalse(AccessPolicy.canManageTournamentTeams(organiser, otherTournament))
        XCTAssertFalse(AccessPolicy.canCreateTournamentMatch(organiser, otherTournament))
        XCTAssertFalse(AccessPolicy.canEnterTournamentResult(organiser, otherTournament))
    }

    func testPlayerCannotEditMatchUnlessOrganiser() {
        let player = makeUser(role: .player)
        let team = makeTeam()
        let participant = Participant(id: UUID(), name: "P", teamId: team.id, elo: 1400)

        let nonOrganiserMatch = Match(
            id: UUID(),
            homeTeam: team,
            awayTeam: team,
            participants: [participant],
            events: [],
            location: "Test",
            startTime: Date(),
            isRatingGame: true,
            isFieldBooked: false,
            maxPlayers: 10,
            ownerId: UUID(),
            organiserIds: []
        )

        let organiserViaListMatch = Match(
            id: UUID(),
            homeTeam: team,
            awayTeam: team,
            participants: [participant],
            events: [],
            location: "Test",
            startTime: Date(),
            isRatingGame: true,
            isFieldBooked: false,
            maxPlayers: 10,
            ownerId: UUID(),
            organiserIds: [player.id]
        )

        XCTAssertFalse(AccessPolicy.canEditMatch(player, nonOrganiserMatch))
        XCTAssertTrue(AccessPolicy.canEditMatch(player, organiserViaListMatch))
    }

    func testOrganiserIdsGrantAccessForMatchAndTournament() {
        let user = makeUser(role: .player)
        let team = makeTeam()
        let participant = Participant(id: UUID(), name: "P", teamId: team.id, elo: 1500)

        let match = Match(
            id: UUID(),
            homeTeam: team,
            awayTeam: team,
            participants: [participant],
            events: [],
            location: "Arena",
            startTime: Date(),
            isRatingGame: true,
            isFieldBooked: true,
            maxPlayers: 10,
            ownerId: UUID(),
            organiserIds: [user.id]
        )

        let tournament = Tournament(
            id: UUID(),
            title: "Cup",
            location: "Arena",
            startDate: Date(),
            teams: [],
            entryFee: 0,
            maxTeams: 8,
            format: "5v5",
            ownerId: UUID(),
            organiserIds: [user.id]
        )

        XCTAssertTrue(AccessPolicy.canEditMatch(user, match))
        XCTAssertTrue(AccessPolicy.canInviteToMatch(user, match))
        XCTAssertTrue(AccessPolicy.canEnterMatchResult(user, match))
        XCTAssertTrue(AccessPolicy.canEditTournament(user, tournament))
        XCTAssertTrue(AccessPolicy.canManageTournamentTeams(user, tournament))
        XCTAssertTrue(AccessPolicy.canCreateTournamentMatch(user, tournament))
        XCTAssertTrue(AccessPolicy.canEnterTournamentResult(user, tournament))
    }

    func testCoachPermissionsRequireActiveStatus() {
        var activeCoach = makeUser(role: .player)
        activeCoach.coachSubscriptionEndsAt = Calendar.current.date(byAdding: .day, value: 3, to: Date())

        var expiredCoach = makeUser(role: .player)
        expiredCoach.coachSubscriptionEndsAt = Calendar.current.date(byAdding: .day, value: -3, to: Date())

        XCTAssertTrue(AccessPolicy.canCreateCoachSession(activeCoach))
        XCTAssertTrue(AccessPolicy.canSearchPlayersAsCoach(activeCoach))
        XCTAssertFalse(AccessPolicy.canCreateCoachSession(expiredCoach))
        XCTAssertFalse(AccessPolicy.canSearchPlayersAsCoach(expiredCoach))
    }

    func testCoachPermissionTransitionsFromActiveToExpired() {
        var coach = makeUser(role: .player)
        coach.coachSubscriptionEndsAt = Calendar.current.date(byAdding: .hour, value: 1, to: Date())

        XCTAssertTrue(AccessPolicy.canCreateCoachSession(coach))
        XCTAssertTrue(AccessPolicy.canSearchPlayersAsCoach(coach))
        XCTAssertEqual(coach.coachStatus, .active)

        coach.coachSubscriptionEndsAt = Calendar.current.date(byAdding: .hour, value: -1, to: Date())

        XCTAssertFalse(AccessPolicy.canCreateCoachSession(coach))
        XCTAssertFalse(AccessPolicy.canSearchPlayersAsCoach(coach))
        XCTAssertEqual(coach.coachStatus, .expired)
    }

    func testPlayerCannotPerformRestrictedActionsWithoutOrganiserAccess() {
        let player = makeUser(role: .player)
        let match = makeMatch(ownerId: UUID())
        let tournament = makeTournament(ownerId: UUID())
        let coachSession = CoachSessionAccessTarget(ownerId: UUID(), organiserIds: [])

        XCTAssertFalse(AccessPolicy.canEditMatch(player, match))
        XCTAssertFalse(AccessPolicy.canInviteToMatch(player, match))
        XCTAssertFalse(AccessPolicy.canEnterMatchResult(player, match))
        XCTAssertFalse(AccessPolicy.canEditTournament(player, tournament))
        XCTAssertFalse(AccessPolicy.canManageTournamentTeams(player, tournament))
        XCTAssertFalse(AccessPolicy.canCreateTournamentMatch(player, tournament))
        XCTAssertFalse(AccessPolicy.canEnterTournamentResult(player, tournament))
        XCTAssertFalse(AccessPolicy.canCreateCoachSession(player))
        XCTAssertFalse(AccessPolicy.canEditCoachSession(player, coachSession))
        XCTAssertFalse(AccessPolicy.canSearchPlayersAsCoach(player))
    }

    private func makeUser(role: GlobalRole) -> User {
        User(
            id: UUID(),
            fullName: "Test User",
            email: "test@example.com",
            favoritePosition: "Pivot",
            city: "Austin",
            eloRating: 1500,
            matchesPlayed: 0,
            wins: 0,
            globalRole: role
        )
    }

    private func makeTeam() -> Team {
        Team(id: UUID(), name: "A", members: [], maxPlayers: 5)
    }

    private func makeMatch(ownerId: UUID) -> Match {
        let u = makeUser(role: .player)
        let team = Team(id: UUID(), name: "A", members: [u], maxPlayers: 5)
        let p = Participant(id: u.id, name: u.fullName, teamId: team.id, elo: u.eloRating)

        return Match(
            id: UUID(),
            homeTeam: team,
            awayTeam: team,
            participants: [p],
            events: [],
            location: "Test",
            startTime: Date(),
            isRatingGame: true,
            isFieldBooked: false,
            maxPlayers: 10,
            ownerId: ownerId,
            organiserIds: [ownerId]
        )
    }

    private func makeTournament(ownerId: UUID) -> Tournament {
        Tournament(
            id: UUID(),
            title: "Test",
            location: "Arena",
            startDate: Date(),
            teams: [],
            entryFee: 10,
            maxTeams: 8,
            format: "5v5",
            ownerId: ownerId,
            organiserIds: [ownerId]
        )
    }
}
