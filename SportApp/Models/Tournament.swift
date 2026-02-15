import Foundation

enum TournamentDisputeStatus: String, CaseIterable {
    case none
    case open
    case resolved
}

struct TournamentMatch: Identifiable, Hashable {
    let id: UUID
    var homeTeamId: UUID
    var awayTeamId: UUID
    var startTime: Date
    var homeScore: Int?
    var awayScore: Int?
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        homeTeamId: UUID,
        awayTeamId: UUID,
        startTime: Date,
        homeScore: Int? = nil,
        awayScore: Int? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.startTime = startTime
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.isCompleted = isCompleted
    }
}

struct Tournament: Identifiable, Hashable {
    let id: UUID
    var title: String
    var location: String
    var startDate: Date
    var teams: [Team]
    var entryFee: Double
    var maxTeams: Int
    var format: String
    var ownerId: UUID
    var organiserIds: [UUID]
    var matches: [TournamentMatch]
    var disputeStatus: TournamentDisputeStatus
    var isDeleted: Bool
    var deletedAt: Date?

    init(
        id: UUID,
        title: String,
        location: String,
        startDate: Date,
        teams: [Team],
        entryFee: Double,
        maxTeams: Int,
        format: String,
        ownerId: UUID,
        organiserIds: [UUID] = [],
        matches: [TournamentMatch] = [],
        disputeStatus: TournamentDisputeStatus = .none,
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.location = location
        self.startDate = startDate
        self.teams = teams
        self.entryFee = entryFee
        self.maxTeams = maxTeams
        self.format = format
        self.ownerId = ownerId
        self.matches = matches
        self.disputeStatus = disputeStatus
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt

        var mergedIds = Set(organiserIds)
        mergedIds.insert(ownerId)
        self.organiserIds = Array(mergedIds)
    }

    var registeredTeams: Int {
        teams.count
    }

    var openSpots: Int {
        max(maxTeams - teams.count, 0)
    }
}
