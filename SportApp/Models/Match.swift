import Foundation

enum RSVPStatus: String, CaseIterable, Identifiable, Codable {
    case invited
    case going
    case maybe
    case declined
    case waitlisted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .invited: return "Invited"
        case .going: return "Going"
        case .maybe: return "Maybe"
        case .declined: return "Declined"
        case .waitlisted: return "Waitlist"
        }
    }
}

enum PositionGroup: String, CaseIterable, Identifiable, Codable {
    case gk = "GK"
    case defenders = "DEF"
    case midfielders = "MID"
    case forwards = "FWD"
    case bench = "BENCH"

    var id: String { rawValue }
}

enum MatchEventType: String, CaseIterable, Identifiable, Codable {
    case goal
    case assist
    case yellow
    case red
    case save

    var id: String { rawValue }

    var title: String {
        switch self {
        case .goal: return "Goal"
        case .assist: return "Assist"
        case .yellow: return "Yellow Card"
        case .red: return "Red Card"
        case .save: return "Save"
        }
    }

    var iconName: String {
        switch self {
        case .goal: return "soccerball"
        case .assist: return "figure.soccer"
        case .yellow: return "rectangle.fill"
        case .red: return "rectangle.fill"
        case .save: return "hand.raised.fill"
        }
    }
}

struct Participant: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var teamId: UUID
    var elo: Int
    var positionGroup: PositionGroup
    var rsvpStatus: RSVPStatus
    var invitedAt: Date
    var waitlistedAt: Date?

    init(
        id: UUID,
        name: String,
        teamId: UUID,
        elo: Int,
        positionGroup: PositionGroup = .bench,
        rsvpStatus: RSVPStatus = .invited,
        invitedAt: Date = Date(),
        waitlistedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.teamId = teamId
        self.elo = elo
        self.positionGroup = positionGroup
        self.rsvpStatus = rsvpStatus
        self.invitedAt = invitedAt
        self.waitlistedAt = waitlistedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case teamId
        case elo
        case positionGroup
        case rsvpStatus
        case invitedAt
        case waitlistedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        teamId = try container.decode(UUID.self, forKey: .teamId)
        elo = try container.decode(Int.self, forKey: .elo)
        positionGroup = try container.decodeIfPresent(PositionGroup.self, forKey: .positionGroup) ?? .bench
        rsvpStatus = try container.decodeIfPresent(RSVPStatus.self, forKey: .rsvpStatus) ?? .invited
        invitedAt = try container.decodeIfPresent(Date.self, forKey: .invitedAt) ?? .distantPast
        waitlistedAt = try container.decodeIfPresent(Date.self, forKey: .waitlistedAt)
    }
}

struct MatchEvent: Identifiable, Hashable, Codable {
    let id: UUID
    let type: MatchEventType
    let minute: Int
    let playerId: UUID
    let createdById: UUID
    let createdAt: Date
}

enum MatchStatus: String, CaseIterable, Codable {
    case scheduled
    case completed
    case cancelled
}

struct Match: Identifiable, Hashable {
    let id: UUID
    var homeTeam: Team
    var awayTeam: Team
    var participants: [Participant]
    var events: [MatchEvent]
    var location: String
    var startTime: Date
    var format: String
    var notes: String
    var isRatingGame: Bool
    var isFieldBooked: Bool
    var isPrivateGame: Bool
    var maxPlayers: Int
    var status: MatchStatus
    var finalHomeScore: Int?
    var finalAwayScore: Int?
    var ownerId: UUID
    var organiserIds: [UUID]

    init(
        id: UUID,
        homeTeam: Team,
        awayTeam: Team,
        participants: [Participant],
        events: [MatchEvent],
        location: String,
        startTime: Date,
        format: String = "5v5",
        notes: String = "",
        isRatingGame: Bool,
        isFieldBooked: Bool,
        isPrivateGame: Bool = false,
        maxPlayers: Int,
        status: MatchStatus = .scheduled,
        finalHomeScore: Int? = nil,
        finalAwayScore: Int? = nil,
        ownerId: UUID,
        organiserIds: [UUID] = []
    ) {
        self.id = id
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.participants = participants
        self.events = events
        self.location = location
        self.startTime = startTime
        self.format = format
        self.notes = notes
        self.isRatingGame = isRatingGame
        self.isFieldBooked = isFieldBooked
        self.isPrivateGame = isPrivateGame
        self.maxPlayers = maxPlayers
        self.status = status
        self.finalHomeScore = finalHomeScore
        self.finalAwayScore = finalAwayScore
        self.ownerId = ownerId

        var mergedIds = Set(organiserIds)
        mergedIds.insert(ownerId)
        self.organiserIds = Array(mergedIds)
    }

    var scoreline: (home: Int, away: Int) {
        if status == .completed, let finalHomeScore, let finalAwayScore {
            return (finalHomeScore, finalAwayScore)
        }

        let participantsByID = Dictionary(
            participants.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let goals = events.filter { $0.type == .goal }

        var homeGoals = 0
        var awayGoals = 0

        for event in goals {
            guard let participant = participantsByID[event.playerId] else { continue }
            if participant.teamId == homeTeam.id {
                homeGoals += 1
            } else if participant.teamId == awayTeam.id {
                awayGoals += 1
            }
        }

        return (homeGoals, awayGoals)
    }
}
