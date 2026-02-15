import Foundation

enum ClubLocation: String, CaseIterable, Identifiable {
    case downtownArena = "Downtown Arena"
    case northSportsCenter = "North Sports Center"
    case westMiniFootballClub = "West Mini Football Club"
    case riversideCourts = "Riverside Courts"
    case cityFiveLeagueHub = "City Five League Hub"

    var id: String { rawValue }
}

enum MatchFormat: String, CaseIterable, Identifiable {
    case fiveVFive = "5v5"
    case sevenVSeven = "7v7"
    case elevenVEleven = "11v11"

    var id: String { rawValue }

    var requiredPlayers: Int {
        switch self {
        case .fiveVFive:
            return 10
        case .sevenVSeven:
            return 14
        case .elevenVEleven:
            return 22
        }
    }

    var defaultMaxPlayers: Int {
        requiredPlayers
    }
}

struct GameDraft {
    var clubLocation: ClubLocation = .downtownArena
    var startAt: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    var durationMinutes = 90
    var format: MatchFormat = .fiveVFive
    var locationName = ""
    var address = ""
    var maxPlayers: Int = MatchFormat.fiveVFive.defaultMaxPlayers
    var isPrivateGame = false
    var hasCourtBooked = false
    var minElo = 1200
    var maxElo = 1800
    var iAmPlaying = true
    var isRatingGame = true
    var anyoneCanInvite = false
    var anyPlayerCanInputResults = false
    var entranceWithoutConfirmation = false
    var notes = ""

    var scheduledDate: Date {
        get { startAt }
        set { startAt = newValue }
    }

    var numberOfPlayers: Int {
        get { maxPlayers }
        set { maxPlayers = newValue }
    }

    var comments: String {
        get { notes }
        set { notes = newValue }
    }
}

struct CreatedGame: Identifiable {
    let id: UUID
    let ownerId: UUID
    let clubLocation: ClubLocation
    let startAt: Date
    let durationMinutes: Int
    let format: MatchFormat
    let locationName: String
    let address: String
    let maxPlayers: Int
    let isPrivateGame: Bool
    let hasCourtBooked: Bool
    let minElo: Int
    let maxElo: Int
    let iAmPlaying: Bool
    let isRatingGame: Bool
    let anyoneCanInvite: Bool
    let anyPlayerCanInputResults: Bool
    let entranceWithoutConfirmation: Bool
    let notes: String
    let createdBy: String
    let inviteLink: String?
    var players: [User]
    var isDeleted: Bool
    var deletedAt: Date?

    var scheduledDate: Date { startAt }
    var numberOfPlayers: Int { maxPlayers }
    var comments: String { notes }

    var averageElo: Int {
        guard !players.isEmpty else { return 0 }
        let total = players.reduce(0) { $0 + $1.eloRating }
        return Int(Double(total) / Double(players.count))
    }
}

enum CreateGameValidationError: LocalizedError {
    case startAtMustBeFuture
    case maxPlayersTooLow(minimum: Int)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .startAtMustBeFuture:
            return "Start date and time must be in the future."
        case .maxPlayersTooLow(let minimum):
            return "Max players must be at least \(minimum) for this format."
        case .unauthorized:
            return AuthorizationUX.permissionDeniedMessage
        }
    }
}

struct PracticeSession: Identifiable {
    let id: UUID
    let title: String
    let location: String
    let startDate: Date
    let numberOfPlayers: Int
    let minElo: Int
    let maxElo: Int
    let isOpenJoin: Bool
    var isDeleted: Bool = false
    var deletedAt: Date? = nil
}

final class AppViewModel: ObservableObject {
#if DEBUG
    struct DebugSwitchUserOption: Identifiable {
        let user: User
        let label: String

        var id: UUID { user.id }
    }

    private static let debugSelectedUserEmailKey = "debug.selectedUserEmail"
#endif

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var users: [User]
    @Published var tournaments: [Tournament]
    @Published var createdGames: [CreatedGame] = []
    @Published var practices: [PracticeSession]
    @Published var authErrorMessage: String?
    @Published var tournamentActionMessage: String?
    @Published var adminActionMessage: String?
    private let matchStore: MatchLocalStore

    init() {
        self.matchStore = UserDefaultsMatchLocalStore()
        let seededUsers = MockDataService.seedUsers()
        let now = Date()
        self.users = seededUsers
        self.tournaments = MockDataService.seedTournaments(availableUsers: seededUsers)
        self.practices = [
            PracticeSession(
                id: UUID(),
                title: "Finishing & Movement",
                location: "Downtown Arena",
                startDate: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now,
                numberOfPlayers: 12,
                minElo: 1100,
                maxElo: 1700,
                isOpenJoin: true,
                isDeleted: false
            ),
            PracticeSession(
                id: UUID(),
                title: "Goalkeeper + Defense Clinic",
                location: "North Sports Center",
                startDate: Calendar.current.date(byAdding: .day, value: 3, to: now) ?? now,
                numberOfPlayers: 10,
                minElo: 1200,
                maxElo: 2000,
                isOpenJoin: false,
                isDeleted: false
            ),
            PracticeSession(
                id: UUID(),
                title: "Small Sided Pressing Drills",
                location: "Riverside Courts",
                startDate: Calendar.current.date(byAdding: .day, value: 6, to: now) ?? now,
                numberOfPlayers: 14,
                minElo: 1000,
                maxElo: 1800,
                isOpenJoin: true,
                isDeleted: false
            )
        ]

#if DEBUG
        restoreDebugSelectedUserIfAvailable()
#endif
    }

    var leaderboard: [User] {
        users.sorted { $0.eloRating > $1.eloRating }
    }

    var visibleTournaments: [Tournament] {
        tournaments.filter { !$0.isDeleted }
    }

    var visibleCreatedGames: [CreatedGame] {
        createdGames.filter { !$0.isDeleted }
    }

    var upcomingCreatedGames: [CreatedGame] {
        let now = Date()
        return visibleCreatedGames
            .filter { game in
                let status = persistedMatchStatus(for: game.id)
                let startTime = persistedMatchStartTime(for: game.id, fallback: game.startAt)
                return status == .scheduled && startTime >= now
            }
            .sorted {
                persistedMatchStartTime(for: $0.id, fallback: $0.startAt)
                    < persistedMatchStartTime(for: $1.id, fallback: $1.startAt)
            }
    }

    var pastCreatedGames: [CreatedGame] {
        let now = Date()
        return visibleCreatedGames
            .filter { game in
                let status = persistedMatchStatus(for: game.id)
                if status == .completed || status == .cancelled {
                    return true
                }
                return persistedMatchStartTime(for: game.id, fallback: game.startAt) < now
            }
            .sorted {
                persistedMatchStartTime(for: $0.id, fallback: $0.startAt)
                    > persistedMatchStartTime(for: $1.id, fallback: $1.startAt)
            }
    }

    var currentUserUpcomingCreatedGames: [CreatedGame] {
        guard let user = currentUser else { return [] }
        return upcomingCreatedGames.filter { isUserParticipantOrOwner(userId: user.id, in: $0) }
    }

    var currentUserPastCreatedGames: [CreatedGame] {
        guard let user = currentUser else { return [] }
        return pastCreatedGames.filter { isUserParticipantOrOwner(userId: user.id, in: $0) }
    }

    var visiblePractices: [PracticeSession] {
        practices.filter { !$0.isDeleted }
    }

    func signIn(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else {
            authErrorMessage = "Please fill in email and password."
            return
        }

        if let existing = users.first(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) {
            if existing.isSuspended {
                authErrorMessage = "This account is suspended. Contact support."
                return
            }
            currentUser = existing
            isAuthenticated = true
            authErrorMessage = nil
            return
        }

        authErrorMessage = "No account found for that email. Please register first."
    }

    func register(name: String, email: String, city: String, favoritePosition: String, password: String) {
        guard !name.isEmpty, !email.isEmpty, !city.isEmpty, !favoritePosition.isEmpty, !password.isEmpty else {
            authErrorMessage = "All fields are required."
            return
        }

        guard users.first(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) == nil else {
            authErrorMessage = "Email already used. Please sign in instead."
            return
        }

        let newUser = User(
            id: UUID(),
            fullName: name,
            email: email,
            favoritePosition: favoritePosition,
            city: city,
            eloRating: 1400,
            matchesPlayed: 0,
            wins: 0,
            globalRole: .player
        )

        users.append(newUser)
        currentUser = newUser
        isAuthenticated = true
        authErrorMessage = nil
    }

    func signOut() {
        currentUser = nil
        isAuthenticated = false
    }

#if DEBUG
    var debugSwitchUserOptions: [DebugSwitchUserOption] {
        let organiserIDs = Set(tournaments.flatMap { [$0.ownerId] + $0.organiserIds })

        let admin = users.first(where: { $0.globalRole == .admin })
        let organiser = users.first(where: { organiserIDs.contains($0.id) && $0.globalRole != .admin })
        let player = users.first(where: { $0.globalRole == .player && !organiserIDs.contains($0.id) })

        let options: [(User?, String)] = [
            (player, "Player"),
            (organiser, "Organiser"),
            (admin, "Admin")
        ]

        var seenEmails = Set<String>()
        return options.compactMap { user, label in
            guard let user else { return nil }
            let key = user.email.lowercased()
            guard !seenEmails.contains(key) else { return nil }
            seenEmails.insert(key)
            return DebugSwitchUserOption(user: user, label: label)
        }
    }

    func debugSwitchUser(to user: User) {
        guard let existing = users.first(where: { $0.email.caseInsensitiveCompare(user.email) == .orderedSame }) else {
            return
        }

        currentUser = existing
        isAuthenticated = true
        authErrorMessage = nil
        UserDefaults.standard.set(existing.email.lowercased(), forKey: Self.debugSelectedUserEmailKey)
    }

    private func restoreDebugSelectedUserIfAvailable() {
        guard let savedEmail = UserDefaults.standard.string(forKey: Self.debugSelectedUserEmailKey) else {
            return
        }
        guard let user = users.first(where: { $0.email.caseInsensitiveCompare(savedEmail) == .orderedSame }) else {
            return
        }
        guard !user.isSuspended else { return }
        currentUser = user
        isAuthenticated = true
    }
#endif

    func createTeamAndJoinTournament(tournamentID: UUID, teamName: String) {
        guard let user = currentUser, !teamName.isEmpty else {
            return
        }

        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }

        guard AccessPolicy.canEditTournament(currentUser, tournaments[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        let alreadyInTeam = tournaments[index].teams.contains { team in
            team.members.contains(where: { $0.id == user.id })
        }
        guard !alreadyInTeam else {
            tournamentActionMessage = "You are already in a tournament team."
            return
        }

        let team = Team(id: UUID(), name: teamName, members: [user], maxPlayers: 6)
        guard tournaments[index].teams.count < tournaments[index].maxTeams else {
            return
        }

        tournaments[index].teams.append(team)
    }

    func joinTeam(tournamentID: UUID, teamID: UUID) {
        guard let user = currentUser else {
            return
        }

        guard let tournamentIndex = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }

        guard let teamIndex = tournaments[tournamentIndex].teams.firstIndex(where: { $0.id == teamID }) else {
            return
        }

        let alreadyInAnotherTeam = tournaments[tournamentIndex].teams.contains { team in
            team.id != teamID && team.members.contains(where: { $0.id == user.id })
        }
        guard !alreadyInAnotherTeam else {
            tournamentActionMessage = "You can only join one team in a tournament."
            return
        }

        var team = tournaments[tournamentIndex].teams[teamIndex]
        if team.members.contains(where: { $0.id == user.id }) || team.isFull {
            return
        }

        team.members.append(user)
        tournaments[tournamentIndex].teams[teamIndex] = team
    }

    func leaveTeam(tournamentID: UUID, teamID: UUID) {
        guard let user = currentUser else {
            return
        }

        guard let tournamentIndex = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }

        guard let teamIndex = tournaments[tournamentIndex].teams.firstIndex(where: { $0.id == teamID }) else {
            return
        }

        let wasMember = tournaments[tournamentIndex].teams[teamIndex].members.contains { $0.id == user.id }
        guard wasMember else {
            return
        }

        tournaments[tournamentIndex].teams[teamIndex].members.removeAll { $0.id == user.id }
        tournamentActionMessage = "You left the team."
    }

    func canCurrentUserEditTournament(_ tournament: Tournament) -> Bool {
        AccessPolicy.canEditTournament(currentUser, tournament)
    }

    func canCurrentUserEnterTournamentResult(_ tournament: Tournament) -> Bool {
        AccessPolicy.canEnterTournamentResult(currentUser, tournament)
    }

    func updateTournamentDetails(
        tournamentID: UUID,
        title: String,
        location: String,
        startDate: Date,
        format: String,
        maxTeams: Int
    ) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }
        guard AccessPolicy.canEditTournament(currentUser, tournaments[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        tournaments[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        tournaments[index].location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        tournaments[index].startDate = startDate
        tournaments[index].format = format.trimmingCharacters(in: .whitespacesAndNewlines)
        tournaments[index].maxTeams = max(maxTeams, tournaments[index].teams.count)
        tournamentActionMessage = "Tournament details updated."
        AuditLogger.log(action: "tournament_updated", actorId: currentUser?.id, objectId: tournamentID)
    }

    func addTeamToTournament(tournamentID: UUID, teamName: String) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }
        guard AccessPolicy.canEditTournament(currentUser, tournaments[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        let trimmedName = teamName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            tournamentActionMessage = "Enter a valid team name."
            return
        }
        guard tournaments[index].teams.count < tournaments[index].maxTeams else {
            tournamentActionMessage = "Tournament is already full."
            return
        }

        let team = Team(id: UUID(), name: trimmedName, members: [], maxPlayers: 6)
        tournaments[index].teams.append(team)
        tournamentActionMessage = "Team added."
        AuditLogger.log(action: "tournament_team_added", actorId: currentUser?.id, objectId: tournamentID, metadata: ["teamName": trimmedName])
    }

    func removeTeamFromTournament(tournamentID: UUID, teamID: UUID) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }
        guard AccessPolicy.canEditTournament(currentUser, tournaments[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        tournaments[index].teams.removeAll { $0.id == teamID }
        tournaments[index].matches.removeAll { $0.homeTeamId == teamID || $0.awayTeamId == teamID }
        tournamentActionMessage = "Team removed."
        AuditLogger.log(action: "tournament_team_removed", actorId: currentUser?.id, objectId: tournamentID, metadata: ["teamId": teamID.uuidString])
    }

    func createTournamentMatch(
        tournamentID: UUID,
        homeTeamID: UUID,
        awayTeamID: UUID,
        startTime: Date
    ) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }
        guard AccessPolicy.canEditTournament(currentUser, tournaments[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard homeTeamID != awayTeamID else {
            tournamentActionMessage = "Home and away team must be different."
            return
        }

        let match = TournamentMatch(homeTeamId: homeTeamID, awayTeamId: awayTeamID, startTime: startTime)
        tournaments[index].matches.append(match)
        tournaments[index].matches.sort { $0.startTime < $1.startTime }
        upsertCreatedGameFromTournamentMatch(tournament: tournaments[index], match: match)
        tournamentActionMessage = "Tournament match scheduled."
        AuditLogger.log(action: "tournament_match_scheduled", actorId: currentUser?.id, objectId: tournamentID, metadata: ["matchId": match.id.uuidString])
    }

    func updateTournamentMatchResult(
        tournamentID: UUID,
        matchID: UUID,
        homeScore: Int,
        awayScore: Int
    ) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }
        guard AccessPolicy.canEnterTournamentResult(currentUser, tournaments[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let matchIndex = tournaments[index].matches.firstIndex(where: { $0.id == matchID }) else {
            return
        }

        tournaments[index].matches[matchIndex].homeScore = max(homeScore, 0)
        tournaments[index].matches[matchIndex].awayScore = max(awayScore, 0)
        tournaments[index].matches[matchIndex].isCompleted = true
        syncCreatedGameCompletion(matchID: matchID, homeScore: homeScore, awayScore: awayScore)
        tournamentActionMessage = "Tournament result saved."
        AuditLogger.log(action: "tournament_result_updated", actorId: currentUser?.id, objectId: tournamentID, metadata: ["matchId": matchID.uuidString, "home": "\(homeScore)", "away": "\(awayScore)"])
    }

    func resolveTournamentDispute(tournamentID: UUID, status: TournamentDisputeStatus) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }
        guard AccessPolicy.canEditTournament(currentUser, tournaments[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        tournaments[index].disputeStatus = status
        tournamentActionMessage = "Dispute status updated to \(status.rawValue)."
        AuditLogger.log(action: "tournament_dispute_status_updated", actorId: currentUser?.id, objectId: tournamentID, metadata: ["status": status.rawValue])
    }

    func simulateMatchResult(didWin: Bool, opponentAverageElo: Int) {
        guard var user = currentUser else {
            return
        }

        user.eloRating = EloService.calculateNewRatings(
            player: user.eloRating,
            opponent: opponentAverageElo,
            didWin: didWin
        )
        user.matchesPlayed += 1
        if didWin {
            user.wins += 1
        }

        currentUser = user

        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
        }
    }

    func applyProfileUpdate(from player: Player) {
        guard var updatedUser = users.first(where: { $0.id == player.id }) else {
            return
        }

        let trimmedName = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            updatedUser.fullName = trimmedName
        }

        let trimmedLocation = player.location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLocation.isEmpty {
            updatedUser.city = trimmedLocation
        }

        updatedUser.avatarImageData = player.avatarImageData
        updatedUser.preferredPositions = player.preferredPositions

        if let firstPreferred = player.preferredPositions.first {
            updatedUser.favoritePosition = firstPreferred.rawValue
        } else if let fallback = player.positions.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            updatedUser.favoritePosition = fallback
        }

        if let index = users.firstIndex(where: { $0.id == updatedUser.id }) {
            users[index] = updatedUser
        }

        if currentUser?.id == updatedUser.id {
            currentUser = updatedUser
        }

        for tournamentIndex in tournaments.indices {
            for teamIndex in tournaments[tournamentIndex].teams.indices {
                if let memberIndex = tournaments[tournamentIndex].teams[teamIndex].members.firstIndex(where: { $0.id == updatedUser.id }) {
                    tournaments[tournamentIndex].teams[teamIndex].members[memberIndex] = updatedUser
                }
            }
        }

        for gameIndex in createdGames.indices {
            for playerIndex in createdGames[gameIndex].players.indices {
                if createdGames[gameIndex].players[playerIndex].id == updatedUser.id {
                    createdGames[gameIndex].players[playerIndex] = updatedUser
                }
            }
        }
    }

    func createGame(from draft: GameDraft, now: Date = Date()) -> Result<CreatedGame, CreateGameValidationError> {
        guard AccessPolicy.canCreateMatch(currentUser) else {
            return .failure(.unauthorized)
        }

        guard draft.startAt > now else {
            return .failure(.startAtMustBeFuture)
        }

        guard draft.maxPlayers >= draft.format.requiredPlayers else {
            return .failure(.maxPlayersTooLow(minimum: draft.format.requiredPlayers))
        }

        let creatorName = currentUser?.fullName ?? "Anonymous Organizer"
        let inviteLink = draft.isPrivateGame ? "https://sportapp.local/invite/\(UUID().uuidString.lowercased())" : nil
        let safeMinElo = min(draft.minElo, draft.maxElo)
        let safeMaxElo = max(draft.minElo, draft.maxElo)
        var selectedPlayers: [User] = []

        if draft.iAmPlaying, let currentUser {
            selectedPlayers.append(currentUser)
        }

        let remainingSlots = max(draft.maxPlayers - selectedPlayers.count, 0)
        let candidatePlayers = users.filter { user in
            let isCurrentUser = user.id == currentUser?.id
            let isInRange = user.eloRating >= safeMinElo && user.eloRating <= safeMaxElo
            return !isCurrentUser && isInRange
        }

        selectedPlayers.append(contentsOf: candidatePlayers.prefix(remainingSlots))

        let game = CreatedGame(
            id: UUID(),
            ownerId: currentUser?.id ?? UUID(),
            clubLocation: draft.clubLocation,
            startAt: draft.startAt,
            durationMinutes: draft.durationMinutes,
            format: draft.format,
            locationName: draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? draft.clubLocation.rawValue : draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            address: draft.address.trimmingCharacters(in: .whitespacesAndNewlines),
            maxPlayers: draft.maxPlayers,
            isPrivateGame: draft.isPrivateGame,
            hasCourtBooked: draft.hasCourtBooked,
            minElo: safeMinElo,
            maxElo: safeMaxElo,
            iAmPlaying: draft.iAmPlaying,
            isRatingGame: draft.isRatingGame,
            anyoneCanInvite: draft.anyoneCanInvite,
            anyPlayerCanInputResults: draft.anyPlayerCanInputResults,
            entranceWithoutConfirmation: draft.entranceWithoutConfirmation,
            notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdBy: creatorName,
            inviteLink: inviteLink,
            players: selectedPlayers,
            isDeleted: false,
            deletedAt: nil
        )

        createdGames.append(game)
        createdGames.sort { $0.scheduledDate < $1.scheduledDate }
        return .success(game)
    }

    func adminUpdateUserRole(userId: UUID, role: GlobalRole) {
        guard AccessPolicy.canManageUsersAsAdmin(currentUser) else {
            adminActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let index = users.firstIndex(where: { $0.id == userId }) else {
            return
        }
        users[index].globalRole = role
        if currentUser?.id == userId {
            currentUser = users[index]
        }
        adminActionMessage = "User role updated."
        AuditLogger.log(action: "admin_user_role_changed", actorId: currentUser?.id, objectId: userId, metadata: ["role": role.rawValue])
    }

    func adminSetSuspended(userId: UUID, isSuspended: Bool, reason: String?) {
        guard AccessPolicy.canManageUsersAsAdmin(currentUser) else {
            adminActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let index = users.firstIndex(where: { $0.id == userId }) else {
            return
        }
        users[index].isSuspended = isSuspended
        users[index].suspensionReason = isSuspended ? reason?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        if currentUser?.id == userId {
            currentUser = users[index]
        }
        adminActionMessage = isSuspended ? "User suspended." : "User unsuspended."
        AuditLogger.log(
            action: isSuspended ? "admin_user_suspended" : "admin_user_unsuspended",
            actorId: currentUser?.id,
            objectId: userId,
            metadata: ["reason": users[index].suspensionReason ?? ""]
        )
    }

    func adminDeleteMatch(gameId: UUID) {
        guard AccessPolicy.canManageUsersAsAdmin(currentUser) else {
            adminActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let index = createdGames.firstIndex(where: { $0.id == gameId }) else {
            return
        }
        createdGames[index].isDeleted = true
        createdGames[index].deletedAt = Date()
        adminActionMessage = "Match deleted (soft)."
        AuditLogger.log(action: "admin_match_deleted", actorId: currentUser?.id, objectId: gameId)
    }

    @discardableResult
    func deleteGameAsOrganiserOrAdmin(gameId: UUID) -> Bool {
        guard let user = currentUser else {
            return false
        }
        guard let index = createdGames.firstIndex(where: { $0.id == gameId }) else {
            return false
        }
        let game = createdGames[index]
        guard user.isAdmin || game.ownerId == user.id else {
            return false
        }

        createdGames[index].isDeleted = true
        createdGames[index].deletedAt = Date()
        AuditLogger.log(action: "match_deleted", actorId: user.id, objectId: gameId)
        return true
    }

    func adminDeleteTournament(tournamentId: UUID) {
        guard AccessPolicy.canManageUsersAsAdmin(currentUser) else {
            adminActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentId }) else {
            return
        }
        tournaments[index].isDeleted = true
        tournaments[index].deletedAt = Date()
        adminActionMessage = "Tournament deleted (soft)."
        AuditLogger.log(action: "admin_tournament_deleted", actorId: currentUser?.id, objectId: tournamentId)
    }

    func adminDeleteSession(sessionId: UUID) {
        guard AccessPolicy.canManageUsersAsAdmin(currentUser) else {
            adminActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let index = practices.firstIndex(where: { $0.id == sessionId }) else {
            return
        }
        practices[index].isDeleted = true
        practices[index].deletedAt = Date()
        adminActionMessage = "Session deleted (soft)."
        AuditLogger.log(action: "admin_session_deleted", actorId: currentUser?.id, objectId: sessionId)
    }

    func refreshGameLists() {
        objectWillChange.send()
    }

    func createdGame(for id: UUID) -> CreatedGame? {
        visibleCreatedGames.first(where: { $0.id == id })
    }

    func syncTournamentMatchesToCreatedGames(tournamentID: UUID) {
        guard let tournament = tournaments.first(where: { $0.id == tournamentID }) else { return }
        for match in tournament.matches {
            upsertCreatedGameFromTournamentMatch(tournament: tournament, match: match)
        }
    }

    private func persistedMatchStatus(for matchId: UUID) -> MatchStatus {
        matchStore.load(matchId: matchId)?.status ?? .scheduled
    }

    private func persistedMatchStartTime(for matchId: UUID, fallback: Date) -> Date {
        matchStore.load(matchId: matchId)?.startTime ?? fallback
    }

    private func isUserParticipantOrOwner(userId: UUID, in game: CreatedGame) -> Bool {
        game.ownerId == userId || game.players.contains(where: { $0.id == userId })
    }

    private func upsertCreatedGameFromTournamentMatch(tournament: Tournament, match: TournamentMatch) {
        let homePlayers = tournament.teams.first(where: { $0.id == match.homeTeamId })?.members ?? []
        let awayPlayers = tournament.teams.first(where: { $0.id == match.awayTeamId })?.members ?? []
        let players = dedupeUsersById(homePlayers + awayPlayers)
        let format = MatchFormat.allCases.first(where: { $0.rawValue == tournament.format }) ?? .fiveVFive
        let inferredMaxPlayers = max(format.requiredPlayers, players.count)
        let eloValues = players.map(\.eloRating)
        let minElo = eloValues.min() ?? 1200
        let maxElo = eloValues.max() ?? 1800
        let createdBy = currentUser?.fullName ?? "Tournament Organiser"

        let game = CreatedGame(
            id: match.id,
            ownerId: tournament.ownerId,
            clubLocation: .cityFiveLeagueHub,
            startAt: match.startTime,
            durationMinutes: 90,
            format: format,
            locationName: tournament.location,
            address: "",
            maxPlayers: inferredMaxPlayers,
            isPrivateGame: false,
            hasCourtBooked: false,
            minElo: minElo,
            maxElo: maxElo,
            iAmPlaying: players.contains(where: { $0.id == currentUser?.id }),
            isRatingGame: true,
            anyoneCanInvite: false,
            anyPlayerCanInputResults: false,
            entranceWithoutConfirmation: false,
            notes: "\(tournament.title) match",
            createdBy: createdBy,
            inviteLink: nil,
            players: players,
            isDeleted: false,
            deletedAt: nil
        )

        if let existingIndex = createdGames.firstIndex(where: { $0.id == game.id }) {
            createdGames[existingIndex] = game
        } else {
            createdGames.append(game)
        }
        createdGames.sort { $0.startAt < $1.startAt }
        refreshGameLists()
    }

    private func syncCreatedGameCompletion(matchID: UUID, homeScore: Int, awayScore: Int) {
        guard let game = createdGames.first(where: { $0.id == matchID }) else { return }
        let existingState = matchStore.load(matchId: matchID)
        let state = MatchLocalState(
            participants: existingState?.participants ?? [],
            events: existingState?.events ?? [],
            location: existingState?.location ?? game.locationName,
            startTime: existingState?.startTime ?? game.startAt,
            format: existingState?.format ?? game.format.rawValue,
            notes: existingState?.notes ?? game.notes,
            maxPlayers: existingState?.maxPlayers ?? game.maxPlayers,
            status: .completed,
            finalHomeScore: homeScore,
            finalAwayScore: awayScore,
            isDeleted: existingState?.isDeleted ?? false
        )
        matchStore.save(matchId: matchID, state: state)
        refreshGameLists()
    }

    private func dedupeUsersById(_ users: [User]) -> [User] {
        var seen = Set<UUID>()
        return users.filter { user in
            seen.insert(user.id).inserted
        }
    }
}
