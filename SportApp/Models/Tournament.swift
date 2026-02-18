import Foundation

enum TournamentDisputeStatus: String, CaseIterable {
    case none
    case open
    case resolved
}

enum TournamentVisibility: String, CaseIterable, Codable {
    case `public`
    case `private`
}

enum TournamentStatus: String, CaseIterable, Codable {
    case draft
    case published
    case completed
    case cancelled
}

enum TournamentMatchStatus: String, CaseIterable, Codable {
    case scheduled
    case completed
    case cancelled
}

struct TournamentTeamMember: Identifiable, Hashable, Codable {
    var id: String { "\(teamId.uuidString)-\(playerId.uuidString)" }
    var teamId: UUID
    var playerId: UUID
    var positionGroup: PositionGroup
    var sortOrder: Int
    var isCaptain: Bool

    init(
        teamId: UUID,
        playerId: UUID,
        positionGroup: PositionGroup = .bench,
        sortOrder: Int = 0,
        isCaptain: Bool = false
    ) {
        self.teamId = teamId
        self.playerId = playerId
        self.positionGroup = positionGroup
        self.sortOrder = sortOrder
        self.isCaptain = isCaptain
    }
}

struct TournamentTeam: Identifiable, Hashable {
    let id: UUID
    var tournamentId: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
}

struct TournamentMatch: Identifiable, Hashable {
    let id: UUID
    var tournamentId: UUID?
    var homeTeamId: UUID
    var awayTeamId: UUID
    var startTime: Date
    var locationName: String?
    var matchday: Int?
    var homeScore: Int?
    var awayScore: Int?
    var status: TournamentMatchStatus

    init(
        id: UUID = UUID(),
        tournamentId: UUID? = nil,
        homeTeamId: UUID,
        awayTeamId: UUID,
        startTime: Date,
        locationName: String? = nil,
        matchday: Int? = nil,
        homeScore: Int? = nil,
        awayScore: Int? = nil,
        status: TournamentMatchStatus = .scheduled
    ) {
        self.id = id
        self.tournamentId = tournamentId
        self.homeTeamId = homeTeamId
        self.awayTeamId = awayTeamId
        self.startTime = startTime
        self.locationName = locationName
        self.matchday = matchday
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.status = status
    }

    init(
        id: UUID = UUID(),
        tournamentId: UUID? = nil,
        homeTeamId: UUID,
        awayTeamId: UUID,
        startTime: Date,
        locationName: String? = nil,
        matchday: Int? = nil,
        homeScore: Int? = nil,
        awayScore: Int? = nil,
        isCompleted: Bool
    ) {
        self.init(
            id: id,
            tournamentId: tournamentId,
            homeTeamId: homeTeamId,
            awayTeamId: awayTeamId,
            startTime: startTime,
            locationName: locationName,
            matchday: matchday,
            homeScore: homeScore,
            awayScore: awayScore,
            status: isCompleted ? .completed : .scheduled
        )
    }

    var isCompleted: Bool {
        status == .completed
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
    var visibility: TournamentVisibility
    var status: TournamentStatus
    var ownerId: UUID
    var organiserIds: [UUID]
    var endDate: Date?
    var teamEntries: [TournamentTeam]
    var teamMembers: [TournamentTeamMember]
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
        visibility: TournamentVisibility = .public,
        status: TournamentStatus = .published,
        ownerId: UUID,
        organiserIds: [UUID] = [],
        endDate: Date? = nil,
        teamEntries: [TournamentTeam] = [],
        teamMembers: [TournamentTeamMember] = [],
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
        self.visibility = visibility
        self.status = status
        self.ownerId = ownerId
        self.endDate = endDate
        self.teamEntries = teamEntries
        self.teamMembers = teamMembers
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

    var name: String {
        get { title }
        set { title = newValue }
    }

    var locationName: String {
        get { location }
        set { location = newValue }
    }

    var startAt: Date {
        get { startDate }
        set { startDate = newValue }
    }
}
