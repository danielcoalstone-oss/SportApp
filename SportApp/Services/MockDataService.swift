import Foundation

enum MockDataService {
    static func seedUsers() -> [User] {
        let now = Date()
        return [
            User(id: UUID(), fullName: "Alex Costa", email: "alex@mini5.app", favoritePosition: "Pivot", city: "Austin", eloRating: 1545, matchesPlayed: 22, wins: 14, globalRole: .player),
            User(id: UUID(), fullName: "Nate Brooks", email: "nate@mini5.app", favoritePosition: "Defender", city: "Dallas", eloRating: 1490, matchesPlayed: 18, wins: 10, globalRole: .admin),
            User(
                id: UUID(),
                fullName: "Ravi Patel",
                email: "ravi@mini5.app",
                favoritePosition: "Winger",
                city: "Houston",
                eloRating: 1615,
                matchesPlayed: 31,
                wins: 20,
                globalRole: .player,
                coachSubscriptionEndsAt: Calendar.current.date(byAdding: .month, value: 1, to: now),
                isCoachSubscriptionPaused: false
            ),
            User(
                id: UUID(),
                fullName: "Olivia Reed",
                email: "olivia@mini5.app",
                favoritePosition: "Goalkeeper",
                city: "Miami",
                eloRating: 1440,
                matchesPlayed: 16,
                wins: 8,
                globalRole: .player,
                organizerSubscriptionEndsAt: Calendar.current.date(byAdding: .month, value: 1, to: now),
                isOrganizerSubscriptionPaused: false
            )
        ]
    }

    static func seedTournaments(availableUsers: [User]) -> [Tournament] {
        var users = availableUsers
        let fallback = User(id: UUID(), fullName: "Guest Player", email: "guest@mini5.app", favoritePosition: "Winger", city: "Unknown", eloRating: 1400, matchesPlayed: 0, wins: 0, globalRole: .player)

        func popUser() -> User {
            if users.isEmpty {
                return fallback
            }
            return users.removeFirst()
        }

        let teamA = Team(id: UUID(), name: "Street Falcons", members: [popUser(), popUser()], maxPlayers: 6)
        let teamB = Team(id: UUID(), name: "North Strikers", members: [popUser()], maxPlayers: 6)

        let teamC = Team(id: UUID(), name: "South Side FC", members: [popUser()], maxPlayers: 6)

        let now = Date()
        let organiserUser = availableUsers.last ?? fallback

        return [
            Tournament(
                id: UUID(),
                title: "Friday Night Mini Cup",
                location: "Austin Sports Dome",
                startDate: Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now,
                teams: [teamA, teamB],
                entryFee: 30,
                maxTeams: 8,
                format: "5v5 Group + Knockout",
                ownerId: organiserUser.id,
                organiserIds: [organiserUser.id]
            ),
            Tournament(
                id: UUID(),
                title: "Weekend Clash Series",
                location: "Houston Arena",
                startDate: Calendar.current.date(byAdding: .day, value: 5, to: now) ?? now,
                teams: [teamC],
                entryFee: 25,
                maxTeams: 10,
                format: "5v5 Swiss",
                ownerId: organiserUser.id,
                organiserIds: [organiserUser.id]
            )
        ]
    }
}
