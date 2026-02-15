import Foundation

struct CoachSessionAccessTarget {
    let ownerId: UUID
    let organiserIds: [UUID]
}

enum AccessPolicy {
    static func canCreateMatch(_ user: User?) -> Bool {
        guard let user else { return false }
        return user.isAdmin || user.globalRole == .player
    }

    static func canEditMatch(_ user: User?, _ match: Match) -> Bool {
        hasAdminOrOrganiserAccess(user, ownerId: match.ownerId, organiserIds: match.organiserIds)
    }

    static func canInviteToMatch(_ user: User?, _ match: Match) -> Bool {
        hasAdminOrOrganiserAccess(user, ownerId: match.ownerId, organiserIds: match.organiserIds)
    }

    static func canEnterMatchResult(_ user: User?, _ match: Match) -> Bool {
        hasAdminOrOrganiserAccess(user, ownerId: match.ownerId, organiserIds: match.organiserIds)
    }

    static func canCreateTournament(_ user: User?) -> Bool {
        guard let user else { return false }
        return user.isAdmin || user.globalRole == .player
    }

    static func canEditTournament(_ user: User?, _ tournament: Tournament) -> Bool {
        hasAdminOrOrganiserAccess(user, ownerId: tournament.ownerId, organiserIds: tournament.organiserIds)
    }

    static func canEnterTournamentResult(_ user: User?, _ tournament: Tournament) -> Bool {
        hasAdminOrOrganiserAccess(user, ownerId: tournament.ownerId, organiserIds: tournament.organiserIds)
    }

    static func canCreateCoachSession(_ user: User?) -> Bool {
        false
    }

    static func canEditCoachSession(_ user: User?, _ session: CoachSessionAccessTarget) -> Bool {
        let _ = session
        return false
    }

    static func canSearchPlayersAsCoach(_ user: User?) -> Bool {
        let _ = user
        return false
    }

    static func canManageUsersAsAdmin(_ user: User?) -> Bool {
        user?.isAdmin == true
    }

    private static func hasAdminOrOrganiserAccess(_ user: User?, ownerId: UUID, organiserIds: [UUID]) -> Bool {
        guard let user else { return false }
        if user.isAdmin { return true }

        let ids = Set(organiserIds).union([ownerId])
        return ids.contains(user.id)
    }
}
