import Foundation

enum GlobalRole: String, CaseIterable, Codable {
    case player
    case admin
}

enum CoachStatus: String, CaseIterable, Codable {
    case none
    case active
    case expired
    case paused
}

struct User: Identifiable, Hashable {
    let id: UUID
    var fullName: String
    var email: String
    var avatarImageData: Data? = nil
    var favoritePosition: String
    var preferredPositions: [FootballPosition] = []
    var city: String
    var eloRating: Int
    var matchesPlayed: Int
    var wins: Int
    var globalRole: GlobalRole = .player
    var coachSubscriptionEndsAt: Date? = nil
    var isCoachSubscriptionPaused = false
    var isSuspended = false
    var suspensionReason: String? = nil

    var winRate: Double {
        guard matchesPlayed > 0 else { return 0 }
        return Double(wins) / Double(matchesPlayed)
    }

    var coachStatus: CoachStatus {
        if isCoachSubscriptionPaused {
            return .paused
        }
        guard let coachSubscriptionEndsAt else {
            return .none
        }
        return coachSubscriptionEndsAt >= Date() ? .active : .expired
    }

    var isAdmin: Bool {
        globalRole == .admin
    }

    var isCoachActive: Bool {
        coachStatus == .active
    }

    var preferredPositionsSummary: String {
        let positions = preferredPositions.map(\.rawValue)
        return positions.isEmpty ? favoritePosition : positions.joined(separator: " • ")
    }
}
