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
    var isDraft = false
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

struct TournamentDraft {
    var title = ""
    var location = ""
    var startAt: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    var hasEndDate = false
    var endAt: Date = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
    var visibility: TournamentVisibility = .public
    var status: TournamentStatus = .published
    var format: MatchFormat = .fiveVFive
    var maxTeams = 8
    var entryFee: Double = 0
    var notes = ""
}

struct PracticeDraft {
    var title = ""
    var location = ""
    var startAt: Date = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
    var durationMinutes = 90
    var numberOfPlayers = 12
    var minElo = 1000
    var maxElo = 2000
    var isOpenJoin = true
    var isDraft = false
    var focusArea = "Technical"
    var notes = ""
}

struct CreatedGame: Identifiable {
    let id: UUID
    let ownerId: UUID
    let organiserIds: [UUID]
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
    var status: MatchStatus = .scheduled
    var isDraft: Bool = false
    var finalHomeScore: Int? = nil
    var finalAwayScore: Int? = nil
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

enum CreateTournamentValidationError: LocalizedError {
    case unauthorized
    case missingTitle
    case missingLocation
    case startAtMustBeFuture
    case endBeforeStart
    case maxTeamsTooLow

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return AuthorizationUX.permissionDeniedMessage
        case .missingTitle:
            return "Tournament name is required."
        case .missingLocation:
            return "Tournament location is required."
        case .startAtMustBeFuture:
            return "Tournament start date must be in the future."
        case .endBeforeStart:
            return "Tournament end date must be after start date."
        case .maxTeamsTooLow:
            return "Tournament requires at least 4 teams."
        }
    }
}

enum CreatePracticeValidationError: LocalizedError {
    case unauthorized
    case missingTitle
    case missingLocation
    case startAtMustBeFuture
    case invalidCapacity

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return AuthorizationUX.permissionDeniedMessage
        case .missingTitle:
            return "Practice title is required."
        case .missingLocation:
            return "Practice location is required."
        case .startAtMustBeFuture:
            return "Practice start time must be in the future."
        case .invalidCapacity:
            return "Number of players must be between 2 and 60."
        }
    }
}

struct CoachReview: Identifiable, Hashable {
    let id: UUID
    let coachID: UUID
    let practiceID: UUID?
    let authorID: UUID
    let authorName: String
    let rating: Int
    let text: String
    let createdAt: Date
}

struct PracticeSession: Identifiable, Hashable {
    let id: UUID
    var title: String
    var location: String
    var startDate: Date
    var durationMinutes: Int
    var numberOfPlayers: Int
    var minElo: Int
    var maxElo: Int
    var isOpenJoin: Bool
    var focusArea: String
    var notes: String
    var ownerId: UUID?
    var organiserIds: [UUID]
    var isDraft: Bool = false
    var isDeleted: Bool = false
    var deletedAt: Date? = nil
}

struct Club: Identifiable, Hashable {
    let id: UUID
    let name: String
    let location: String
    let phoneNumber: String
    let bookingHint: String
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
    @Published var isAuthLoading = false
    @Published var isBootstrapping = true
    @Published var currentUser: User?
    @Published var users: [User]
    @Published var tournaments: [Tournament]
    @Published var createdGames: [CreatedGame] = []
    @Published var practices: [PracticeSession]
    @Published var joinedPracticeIDs: Set<UUID> = []
    @Published var coachReviewsByCoach: [UUID: [CoachReview]] = [:]
    @Published var clubs: [Club]
    @Published var authErrorMessage: String?
    @Published var tournamentActionMessage: String?
    @Published var adminActionMessage: String?
    private let matchStore: MatchLocalStore
    private let supabaseEnvironment: SupabaseEnvironment
    private let supabaseAuthService: SupabaseAuthService?
    private let supabaseDataService: SupabaseDataService?
    private var authenticatedSupabaseUserID: UUID?

    init() {
        self.matchStore = UserDefaultsMatchLocalStore()
        self.supabaseEnvironment = SupabaseEnvironment.shared
        self.supabaseAuthService = supabaseEnvironment.authService
        self.supabaseDataService = supabaseEnvironment.dataService
        let seededUsers = MockDataService.seedUsers()
        let now = Date()
        self.users = seededUsers
        self.tournaments = MockDataService.seedTournaments(availableUsers: seededUsers)
        let coachOwner = seededUsers.first(where: { $0.isCoachActive })?.id
        self.practices = [
            PracticeSession(
                id: UUID(),
                title: "Finishing & Movement",
                location: "Downtown Arena",
                startDate: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now,
                durationMinutes: 90,
                numberOfPlayers: 12,
                minElo: 1100,
                maxElo: 1700,
                isOpenJoin: true,
                focusArea: "Finishing",
                notes: "Bring cones and light bibs.",
                ownerId: coachOwner,
                organiserIds: coachOwner.map { [$0] } ?? [],
                isDeleted: false
            ),
            PracticeSession(
                id: UUID(),
                title: "Goalkeeper + Defense Clinic",
                location: "North Sports Center",
                startDate: Calendar.current.date(byAdding: .day, value: 3, to: now) ?? now,
                durationMinutes: 90,
                numberOfPlayers: 10,
                minElo: 1200,
                maxElo: 2000,
                isOpenJoin: false,
                focusArea: "Defensive shape",
                notes: "Focus on 1v1 and transition defense.",
                ownerId: coachOwner,
                organiserIds: coachOwner.map { [$0] } ?? [],
                isDeleted: false
            ),
            PracticeSession(
                id: UUID(),
                title: "Small Sided Pressing Drills",
                location: "Riverside Courts",
                startDate: Calendar.current.date(byAdding: .day, value: 6, to: now) ?? now,
                durationMinutes: 75,
                numberOfPlayers: 14,
                minElo: 1000,
                maxElo: 1800,
                isOpenJoin: true,
                focusArea: "Pressing",
                notes: "High-intensity, bring water.",
                ownerId: coachOwner,
                organiserIds: coachOwner.map { [$0] } ?? [],
                isDeleted: false
            )
        ]
        if let coachOwner {
            self.coachReviewsByCoach = [
                coachOwner: [
                    CoachReview(
                        id: UUID(),
                        coachID: coachOwner,
                        practiceID: nil,
                        authorID: seededUsers.first(where: { $0.id != coachOwner })?.id ?? coachOwner,
                        authorName: seededUsers.first(where: { $0.id != coachOwner })?.fullName ?? "Player",
                        rating: 5,
                        text: "Great session structure and clear feedback.",
                        createdAt: now
                    )
                ]
            ]
        } else {
            self.coachReviewsByCoach = [:]
        }
        self.clubs = [
            Club(
                id: UUID(),
                name: "Downtown Arena",
                location: "Austin, TX",
                phoneNumber: "+1 (512) 555-0181",
                bookingHint: "Booking will be connected later through Yclients or phone."
            ),
            Club(
                id: UUID(),
                name: "North Sports Center",
                location: "Dallas, TX",
                phoneNumber: "+1 (214) 555-0134",
                bookingHint: "Booking will be connected later through Yclients or phone."
            ),
            Club(
                id: UUID(),
                name: "Riverside Courts",
                location: "Houston, TX",
                phoneNumber: "+1 (713) 555-0179",
                bookingHint: "Booking will be connected later through Yclients or phone."
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

    var visibleTournamentDrafts: [Tournament] {
        visibleTournaments
            .filter { $0.status == .draft }
            .sorted { $0.startDate < $1.startDate }
    }

    var visibleCreatedGames: [CreatedGame] {
        createdGames.filter { !$0.isDeleted && !$0.isDraft }
    }

    var visibleGameDrafts: [CreatedGame] {
        createdGames
            .filter { !$0.isDeleted && $0.isDraft }
            .sorted { $0.startAt < $1.startAt }
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

    var thisWeekQuickBookingGames: [CreatedGame] {
        let now = Date()
        let next24Hours = now.addingTimeInterval(24 * 60 * 60)

        return discoverableUpcomingCreatedGames.filter { game in
            let startTime = persistedMatchStartTime(for: game.id, fallback: game.startAt)
            return startTime >= now && startTime <= next24Hours
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
        guard currentUser != nil else { return [] }
        return upcomingCreatedGames.filter { game in
            currentUserRSVPStatus(in: game) == .going
        }
    }

    var discoverableUpcomingCreatedGames: [CreatedGame] {
        guard let user = currentUser else {
            return upcomingCreatedGames
        }

        return upcomingCreatedGames.filter { game in
            if game.ownerId == user.id {
                return false
            }

            if game.isPrivateGame {
                return false
            }

            guard let status = currentUserRSVPStatus(in: game) else {
                return true
            }

            switch status {
            case .invited, .going, .maybe, .waitlisted:
                return false
            case .declined:
                return true
            }
        }
    }

    var currentUserPastCreatedGames: [CreatedGame] {
        guard let user = currentUser else { return [] }
        return pastCreatedGames.filter { game in
            if isUserParticipantOrOwner(userId: user.id, in: game) {
                return true
            }
            // If current user had RSVP "going", treat as attended and keep in Past.
            return currentUserRSVPStatus(in: game) == .going
        }
    }

    var currentUserUpcomingTournaments: [Tournament] {
        guard let user = currentUser else { return [] }
        return visibleTournaments
            .filter { isUserInTournament(userId: user.id, in: $0) && !isTournamentPast($0) }
            .sorted { $0.startDate < $1.startDate }
    }

    var currentUserPastTournaments: [Tournament] {
        guard let user = currentUser else { return [] }
        return visibleTournaments
            .filter { isUserInTournament(userId: user.id, in: $0) && isTournamentPast($0) }
            .sorted { $0.startDate > $1.startDate }
    }

    var canCurrentUserCreateTournamentFromCreateTab: Bool {
        AccessPolicy.canCreateTournament(currentUser)
    }

    var canCurrentUserCreatePracticeFromCreateTab: Bool {
        AccessPolicy.canCreateCoachSession(currentUser)
    }

    func user(with id: UUID) -> User? {
        users.first(where: { $0.id == id })
    }

    func upcomingCreatedGames(for userID: UUID) -> [CreatedGame] {
        upcomingCreatedGames.filter { isUserParticipantOrOwner(userId: userID, in: $0) }
    }

    func pastCreatedGames(for userID: UUID) -> [CreatedGame] {
        pastCreatedGames.filter { isUserParticipantOrOwner(userId: userID, in: $0) }
    }

    func upcomingTournaments(for userID: UUID) -> [Tournament] {
        visibleTournaments
            .filter { isUserInTournament(userId: userID, in: $0) && !isTournamentPast($0) }
            .sorted { $0.startDate < $1.startDate }
    }

    func pastTournaments(for userID: UUID) -> [Tournament] {
        visibleTournaments
            .filter { isUserInTournament(userId: userID, in: $0) && isTournamentPast($0) }
            .sorted { $0.startDate > $1.startDate }
    }

    func partnersCount(for userID: UUID) -> Int {
        var partners = Set<UUID>()

        for game in visibleCreatedGames where isUserParticipantOrOwner(userId: userID, in: game) {
            for player in game.players where player.id != userID {
                partners.insert(player.id)
            }
        }

        for tournament in visibleTournaments where isUserInTournament(userId: userID, in: tournament) {
            for team in tournament.teams where team.members.contains(where: { $0.id == userID }) {
                for member in team.members where member.id != userID {
                    partners.insert(member.id)
                }
            }
        }

        return partners.count
    }

    func canCurrentUserSeeTournament(_ tournament: Tournament) -> Bool {
        guard tournament.visibility == .private else { return true }
        guard let user = currentUser else { return false }
        return user.isAdmin || isUserInTournament(userId: user.id, in: tournament)
    }

    var visiblePractices: [PracticeSession] {
        practices.filter { !$0.isDeleted && !$0.isDraft }
    }

    func isCurrentUserJoinedPractice(_ practiceID: UUID) -> Bool {
        joinedPracticeIDs.contains(practiceID)
    }

    var visiblePracticeDrafts: [PracticeSession] {
        practices
            .filter { !$0.isDeleted && $0.isDraft }
            .sorted { $0.startDate < $1.startDate }
    }

    var currentUserTournamentDrafts: [Tournament] {
        guard let user = currentUser else { return [] }
        return visibleTournamentDrafts.filter {
            $0.ownerId == user.id || $0.organiserIds.contains(user.id)
        }
    }

    var currentUserPracticeDrafts: [PracticeSession] {
        guard currentUser != nil else { return [] }
        return visiblePracticeDrafts.filter { canCurrentUserEditPractice($0) }
    }

    var currentUserGameDrafts: [CreatedGame] {
        guard let user = currentUser else { return [] }
        return visibleGameDrafts.filter { $0.ownerId == user.id }
    }

    var canCurrentUserSeeTournamentDrafts: Bool {
        canCurrentUserCreateTournamentFromCreateTab
    }

    var canCurrentUserSeePracticeDrafts: Bool {
        canCurrentUserCreatePracticeFromCreateTab
    }

    var isUsingSupabase: Bool {
        supabaseEnvironment.isConfigured
    }

    func bootstrap() async {
        await MainActor.run {
            isBootstrapping = true
        }
        defer {
            Task { @MainActor in
                self.isBootstrapping = false
            }
        }

        guard isUsingSupabase, let supabaseAuthService else {
            return
        }
        guard supabaseAuthService.hasSession else {
            return
        }

        do {
            let authUser = try await supabaseAuthService.currentUser()
            authenticatedSupabaseUserID = authUser.id
            try await syncFromBackend(currentUserID: authUser.id, fallbackEmail: authUser.email)
            await MainActor.run {
                isAuthenticated = true
                authErrorMessage = nil
            }
        } catch {
            await MainActor.run {
                authErrorMessage = "Backend session expired. Please sign in again."
                isAuthenticated = false
                currentUser = nil
            }
        }
    }

    func makePlayerProfileRepository(for user: User) -> any PlayerProfileRepository {
        if let supabaseDataService {
            return SupabasePlayerProfileRepository(dataService: supabaseDataService, email: user.email)
        }
        return MockPlayerProfileRepository(seedPlayer: Player.from(user: user))
    }

    func signIn(email: String, password: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !normalizedPassword.isEmpty else {
            authErrorMessage = "Please fill in email and password."
            return
        }

        if let supabaseAuthService {
            isAuthLoading = true
            Task {
                defer {
                    Task { @MainActor in
                        self.isAuthLoading = false
                    }
                }
                do {
                    let session = try await supabaseAuthService.signIn(email: normalizedEmail, password: normalizedPassword)
                    authenticatedSupabaseUserID = session.user.id
                    try await syncFromBackend(currentUserID: session.user.id, fallbackEmail: session.user.email ?? normalizedEmail)
                    await MainActor.run {
                        isAuthenticated = true
                        authErrorMessage = nil
                    }
                } catch {
                    await MainActor.run {
                        let message = error.localizedDescription
                        if message.localizedCaseInsensitiveContains("email not confirmed") {
                            authErrorMessage = "Please confirm your email first, then sign in."
                        } else if message.localizedCaseInsensitiveContains("invalid login credentials") {
                            authErrorMessage = "Invalid email or password."
                        } else {
                            authErrorMessage = message
                        }
                        isAuthenticated = false
                    }
                }
            }
            return
        }

        if let existing = users.first(where: { $0.email.caseInsensitiveCompare(normalizedEmail) == .orderedSame }) {
            if existing.isSuspended {
                authErrorMessage = "This account is suspended. Contact support."
                return
            }
            currentUser = existing
            isAuthenticated = true
            authErrorMessage = nil
            if !isUsingSupabase {
                seedLocalDemoCreatedGames(for: currentUser, users: users)
                joinedPracticeIDs = []
            }
            return
        }

        authErrorMessage = "No account found for that email. Please register first."
    }

    func register(name: String, email: String, city: String, favoritePosition: String, password: String) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedFavoritePosition = favoritePosition.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedName.isEmpty, !normalizedEmail.isEmpty, !normalizedCity.isEmpty, !normalizedFavoritePosition.isEmpty, !normalizedPassword.isEmpty else {
            authErrorMessage = "All fields are required."
            return
        }

        if let supabaseAuthService, let supabaseDataService {
            isAuthLoading = true
            Task {
                defer {
                    Task { @MainActor in
                        self.isAuthLoading = false
                    }
                }
                do {
                    let maybeSession = try await supabaseAuthService.signUp(email: normalizedEmail, password: normalizedPassword)
                    guard let session = maybeSession else {
                        await MainActor.run {
                            authErrorMessage = "Registration submitted. Check your email to confirm your account."
                        }
                        return
                    }

                    let player = Player(
                        id: session.user.id,
                        name: normalizedName,
                        avatarURL: "",
                        avatarImageData: nil,
                        positions: [normalizedFavoritePosition],
                        preferredPositions: [],
                        preferredFoot: .right,
                        skillLevel: 5,
                        location: normalizedCity,
                        createdAt: Date()
                    )
                    authenticatedSupabaseUserID = session.user.id
                    try await supabaseDataService.saveProfile(player, email: normalizedEmail)
                    try await syncFromBackend(currentUserID: session.user.id, fallbackEmail: session.user.email ?? normalizedEmail)
                    await MainActor.run {
                        isAuthenticated = true
                        authErrorMessage = nil
                    }
                } catch {
                    await MainActor.run {
                        authErrorMessage = error.localizedDescription
                        isAuthenticated = false
                    }
                }
            }
            return
        }

        guard users.first(where: { $0.email.caseInsensitiveCompare(normalizedEmail) == .orderedSame }) == nil else {
            authErrorMessage = "Email already used. Please sign in instead."
            return
        }

        let newUser = User(
            id: UUID(),
            fullName: normalizedName,
            email: normalizedEmail,
            favoritePosition: normalizedFavoritePosition,
            city: normalizedCity,
            eloRating: 1400,
            matchesPlayed: 0,
            wins: 0,
            globalRole: .player
        )

        users.append(newUser)
        currentUser = newUser
        isAuthenticated = true
        authErrorMessage = nil
        if !isUsingSupabase {
            seedLocalDemoCreatedGames(for: currentUser, users: users)
            joinedPracticeIDs = []
        }
    }

    func signOut() {
        if let supabaseAuthService {
            Task {
                await supabaseAuthService.signOut()
            }
        }
        authenticatedSupabaseUserID = nil
        joinedPracticeIDs = []
        currentUser = nil
        isAuthenticated = false
    }

#if DEBUG
    var debugSwitchUserOptions: [DebugSwitchUserOption] {
        let options: [(User, String)] = [
            (debugUser(for: "player"), "Player"),
            (debugUser(for: "organizer"), "Organizer"),
            (debugUser(for: "coach"), "Coach"),
            (debugUser(for: "admin"), "Admin")
        ]
        return options.map { DebugSwitchUserOption(user: $0.0, label: $0.1) }
    }

    func debugSwitchUser(to user: User) {
        if let index = users.firstIndex(where: { $0.email.caseInsensitiveCompare(user.email) == .orderedSame }) {
            users[index] = user
            currentUser = users[index]
        } else {
            users.append(user)
            currentUser = user
        }
        isAuthenticated = true
        authErrorMessage = nil
        if !isUsingSupabase {
            seedLocalDemoCreatedGames(for: currentUser, users: users)
            joinedPracticeIDs = []
        }
        UserDefaults.standard.set(user.email.lowercased(), forKey: Self.debugSelectedUserEmailKey)
    }

    private func debugUser(for access: String) -> User {
        let base = currentUser ?? users.first ?? User(
            id: UUID(),
            fullName: "Debug User",
            email: "debug@local.app",
            favoritePosition: "Midfielder",
            city: "Debug City",
            eloRating: 1400,
            matchesPlayed: 0,
            wins: 0,
            globalRole: .player
        )

        let role: GlobalRole = access == "admin" ? .admin : .player
        let coachEnds: Date? = access == "coach" ? Calendar.current.date(byAdding: .day, value: 30, to: Date()) : nil
        let organizerEnds: Date? = access == "organizer" ? Calendar.current.date(byAdding: .day, value: 30, to: Date()) : nil

        return User(
            id: UUID(),
            fullName: "Debug \(access.capitalized)",
            email: "debug+\(access)@local.app",
            avatarURL: base.avatarURL,
            avatarImageData: base.avatarImageData,
            favoritePosition: base.favoritePosition,
            preferredPositions: base.preferredPositions,
            city: base.city,
            eloRating: base.eloRating,
            matchesPlayed: base.matchesPlayed,
            wins: base.wins,
            draws: base.draws,
            losses: base.losses,
            globalRole: role,
            coachSubscriptionEndsAt: coachEnds,
            isCoachSubscriptionPaused: false,
            organizerSubscriptionEndsAt: organizerEnds,
            isOrganizerSubscriptionPaused: false,
            isSuspended: false,
            suspensionReason: nil
        )
    }

    private func restoreDebugSelectedUserIfAvailable() {
        guard let savedEmail = UserDefaults.standard.string(forKey: Self.debugSelectedUserEmailKey) else {
            return
        }
        if let user = users.first(where: { $0.email.caseInsensitiveCompare(savedEmail) == .orderedSame }) {
            guard !user.isSuspended else { return }
            currentUser = user
            isAuthenticated = true
            if !isUsingSupabase {
                seedLocalDemoCreatedGames(for: currentUser, users: users)
            }
            return
        }

        let savedAccess: String
        if savedEmail.contains("debug+organizer@") {
            savedAccess = "organizer"
        } else if savedEmail.contains("debug+coach@") {
            savedAccess = "coach"
        } else if savedEmail.contains("debug+admin@") {
            savedAccess = "admin"
        } else if savedEmail.contains("debug+player@") {
            savedAccess = "player"
        } else {
            return
        }

        let restored = debugUser(for: savedAccess)
        users.append(restored)
        currentUser = restored
        isAuthenticated = true
        if !isUsingSupabase {
            seedLocalDemoCreatedGames(for: currentUser, users: users)
        }
    }
#endif

    func createTeamAndJoinTournament(tournamentID: UUID, teamName: String) {
        guard !teamName.isEmpty else {
            return
        }

        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }

        guard AccessPolicy.canManageTournamentTeams(currentUser, tournaments[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        let team = Team(id: UUID(), name: teamName, members: [], maxPlayers: 6)
        let teamEntry = TournamentTeam(
            id: team.id,
            tournamentId: tournamentID,
            name: teamName,
            colorHex: "#2D6CC4",
            createdAt: Date()
        )
        guard tournaments[index].teams.count < tournaments[index].maxTeams else {
            return
        }

        tournaments[index].teams.append(team)
        tournaments[index].teamEntries.append(teamEntry)
        tournamentActionMessage = "Team created."

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.createTournamentTeam(tournamentID: tournamentID, team: team)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Team created locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func joinTeam(tournamentID: UUID, teamID: UUID) {
        guard let user = currentUser else {
            return
        }

        guard let tournamentIndex = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }

        if tournaments[tournamentIndex].visibility == .private,
           !AccessPolicy.canManageTournamentTeams(currentUser, tournaments[tournamentIndex]) {
            tournamentActionMessage = "Private tournament. Join via invite link."
            return
        }

        guard let teamIndex = tournaments[tournamentIndex].teams.firstIndex(where: { $0.id == teamID }) else {
            return
        }

        let isTournamentOrganiser = tournaments[tournamentIndex].ownerId == user.id
            || tournaments[tournamentIndex].organiserIds.contains(user.id)
        if isTournamentOrganiser {
            tournamentActionMessage = "Organiser cannot join tournament teams in own tournament."
            return
        }

        guard tournaments[tournamentIndex].status == .published else {
            tournamentActionMessage = "You can only join teams in active tournaments."
            return
        }

        if tournaments[tournamentIndex].startDate < Date() && !tournaments[tournamentIndex].matches.contains(where: { $0.status == .scheduled }) {
            tournamentActionMessage = "Tournament is finished. Team join is closed."
            return
        }

        let hasUpcomingMatch = tournaments[tournamentIndex].matches.contains { match in
            match.status == .scheduled
        }
        if !hasUpcomingMatch && !tournaments[tournamentIndex].matches.isEmpty {
            tournamentActionMessage = "Tournament is finished. Team join is closed."
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
        if team.members.contains(where: { $0.id == user.id }) {
            return
        }
        if team.isFull {
            tournamentActionMessage = "Team is full."
            return
        }

        team.members.append(user)
        tournaments[tournamentIndex].teams[teamIndex] = team
        let nextOrder = tournaments[tournamentIndex].teamMembers
            .filter { $0.teamId == teamID }
            .map(\.sortOrder)
            .max() ?? -1
        tournaments[tournamentIndex].teamMembers.append(
            TournamentTeamMember(
                teamId: teamID,
                playerId: user.id,
                positionGroup: .bench,
                sortOrder: nextOrder + 1,
                isCaptain: false
            )
        )
        tournamentActionMessage = "Joined team."

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.addTournamentTeamMember(tournamentID: tournamentID, teamID: teamID, userID: user.id)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    @discardableResult
    func joinCreatedGame(gameID: UUID) -> Bool {
        guard let user = currentUser else { return false }
        guard let index = createdGames.firstIndex(where: { $0.id == gameID }) else { return false }

        let game = createdGames[index]
        guard persistedMatchStatus(for: game.id) == .scheduled else {
            tournamentActionMessage = "Only upcoming games can be joined."
            return false
        }
        if game.isPrivateGame,
           !user.isAdmin,
           game.ownerId != user.id,
           !game.organiserIds.contains(user.id) {
            tournamentActionMessage = "Private game. Join via invite link."
            return false
        }

        guard currentUserRSVPStatus(in: game) != .going else {
            tournamentActionMessage = "You already joined this game."
            return false
        }

        if game.players.count >= game.maxPlayers {
            tournamentActionMessage = "Game is full."
            return false
        }

        if !game.players.contains(where: { $0.id == user.id }) {
            createdGames[index].players.append(user)
        }
        persistCurrentUserRSVP(matchID: gameID, game: createdGames[index], status: .going)
        tournamentActionMessage = "You joined the game."

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.setMatchRSVP(matchID: gameID, userID: user.id, status: .going)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Joined locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
        return true
    }

    func leaveCreatedGame(gameID: UUID) {
        guard let user = currentUser else { return }
        guard let index = createdGames.firstIndex(where: { $0.id == gameID }) else { return }
        guard persistedMatchStatus(for: createdGames[index].id) == .scheduled else { return }
        guard currentUserRSVPStatus(in: createdGames[index]) == .going else { return }
        guard createdGames[index].ownerId != user.id else {
            tournamentActionMessage = "Owner cannot leave own game."
            return
        }
        guard createdGames[index].players.contains(where: { $0.id == user.id }) else {
            return
        }

        createdGames[index].players.removeAll { $0.id == user.id }
        persistCurrentUserRSVP(matchID: gameID, game: createdGames[index], status: .declined)
        tournamentActionMessage = "You left the game."

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.setMatchRSVP(matchID: gameID, userID: user.id, status: .declined)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Left locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func joinPractice(sessionID: UUID) {
        guard let user = currentUser else { return }
        guard let index = practices.firstIndex(where: { $0.id == sessionID }) else { return }

        let session = practices[index]
        if isPracticeFinished(session) {
            tournamentActionMessage = "Practice is finished. Join is closed."
            return
        }
        let canManage = canCurrentUserEditPractice(session)
        if !session.isOpenJoin && !canManage {
            tournamentActionMessage = "Private practice. Join via invite link."
            return
        }

        if joinedPracticeIDs.contains(sessionID) {
            tournamentActionMessage = "You already joined this practice."
            return
        }

        joinedPracticeIDs.insert(sessionID)
        tournamentActionMessage = "You joined the practice."

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.joinPractice(practiceID: sessionID, userID: user.id)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Joined locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func leavePractice(sessionID: UUID) {
        guard let user = currentUser else { return }
        guard let session = practices.first(where: { $0.id == sessionID }) else { return }
        if isPracticeFinished(session) {
            tournamentActionMessage = "Practice is finished. Join/leave is locked."
            return
        }
        guard joinedPracticeIDs.contains(sessionID) else { return }

        joinedPracticeIDs.remove(sessionID)
        tournamentActionMessage = "You left the practice."

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.leavePractice(practiceID: sessionID, userID: user.id)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Left locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func leaveTeam(tournamentID: UUID, teamID: UUID) {
        guard let user = currentUser else {
            return
        }

        guard let tournamentIndex = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }

        guard tournaments[tournamentIndex].status == .published else {
            tournamentActionMessage = "Tournament is finished. Team changes are locked."
            return
        }

        if tournaments[tournamentIndex].startDate < Date() && !tournaments[tournamentIndex].matches.contains(where: { $0.status == .scheduled }) {
            tournamentActionMessage = "Tournament is finished. Team changes are locked."
            return
        }

        let hasUpcomingMatch = tournaments[tournamentIndex].matches.contains { match in
            match.status == .scheduled
        }
        if !hasUpcomingMatch && !tournaments[tournamentIndex].matches.isEmpty {
            tournamentActionMessage = "Tournament is finished. Team changes are locked."
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
        tournaments[tournamentIndex].teamMembers.removeAll {
            $0.teamId == teamID && $0.playerId == user.id
        }
        tournamentActionMessage = "You left the team."

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.removeTournamentTeamMember(
                        tournamentID: tournamentID,
                        teamID: teamID,
                        userID: user.id
                    )
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Left team locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func addPlayerToTournamentTeam(tournamentID: UUID, teamID: UUID, userID: UUID) {
        guard let tournamentIndex = tournaments.firstIndex(where: { $0.id == tournamentID }) else { return }
        guard AccessPolicy.canManageTournamentTeams(currentUser, tournaments[tournamentIndex]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let teamIndex = tournaments[tournamentIndex].teams.firstIndex(where: { $0.id == teamID }) else { return }
        guard let user = users.first(where: { $0.id == userID }) else { return }
        guard !tournaments[tournamentIndex].teams.contains(where: { $0.members.contains(where: { $0.id == userID }) }) else {
            tournamentActionMessage = "Player is already assigned to a team."
            return
        }
        guard !tournaments[tournamentIndex].teams[teamIndex].isFull else {
            tournamentActionMessage = "Team is full."
            return
        }

        tournaments[tournamentIndex].teams[teamIndex].members.append(user)
        let nextOrder = tournaments[tournamentIndex].teamMembers
            .filter { $0.teamId == teamID }
            .map(\.sortOrder)
            .max() ?? -1
        tournaments[tournamentIndex].teamMembers.append(
            TournamentTeamMember(teamId: teamID, playerId: userID, positionGroup: .bench, sortOrder: nextOrder + 1, isCaptain: false)
        )

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.addTournamentTeamMember(
                        tournamentID: tournamentID,
                        teamID: teamID,
                        userID: userID,
                        positionGroup: .bench,
                        sortOrder: nextOrder + 1,
                        isCaptain: false
                    )
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Added locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func removePlayerFromTournamentTeam(tournamentID: UUID, teamID: UUID, userID: UUID) {
        guard let tournamentIndex = tournaments.firstIndex(where: { $0.id == tournamentID }) else { return }
        guard AccessPolicy.canManageTournamentTeams(currentUser, tournaments[tournamentIndex]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let teamIndex = tournaments[tournamentIndex].teams.firstIndex(where: { $0.id == teamID }) else { return }

        tournaments[tournamentIndex].teams[teamIndex].members.removeAll { $0.id == userID }
        tournaments[tournamentIndex].teamMembers.removeAll { $0.teamId == teamID && $0.playerId == userID }

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.removeTournamentTeamMember(
                        tournamentID: tournamentID,
                        teamID: teamID,
                        userID: userID
                    )
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Removed locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func updateTournamentMemberPositionGroup(
        tournamentID: UUID,
        teamID: UUID,
        userID: UUID,
        group: PositionGroup
    ) {
        guard let tournamentIndex = tournaments.firstIndex(where: { $0.id == tournamentID }) else { return }
        guard AccessPolicy.canManageTournamentTeams(currentUser, tournaments[tournamentIndex]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let memberIndex = tournaments[tournamentIndex].teamMembers.firstIndex(where: { $0.teamId == teamID && $0.playerId == userID }) else { return }
        tournaments[tournamentIndex].teamMembers[memberIndex].positionGroup = group

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateTournamentTeamMember(
                        tournamentID: tournamentID,
                        teamID: teamID,
                        userID: userID,
                        positionGroup: group,
                        sortOrder: nil,
                        isCaptain: nil
                    )
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Saved locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func setTournamentCaptain(tournamentID: UUID, teamID: UUID, userID: UUID) {
        guard let tournamentIndex = tournaments.firstIndex(where: { $0.id == tournamentID }) else { return }
        guard AccessPolicy.canManageTournamentTeams(currentUser, tournaments[tournamentIndex]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        let teamMemberIndices = tournaments[tournamentIndex].teamMembers.indices.filter {
            tournaments[tournamentIndex].teamMembers[$0].teamId == teamID
        }
        guard !teamMemberIndices.isEmpty else { return }

        for idx in teamMemberIndices {
            tournaments[tournamentIndex].teamMembers[idx].isCaptain = tournaments[tournamentIndex].teamMembers[idx].playerId == userID
        }

        if let supabaseDataService {
            Task {
                do {
                    for idx in teamMemberIndices {
                        let member = tournaments[tournamentIndex].teamMembers[idx]
                        try await supabaseDataService.updateTournamentTeamMember(
                            tournamentID: tournamentID,
                            teamID: teamID,
                            userID: member.playerId,
                            positionGroup: nil,
                            sortOrder: nil,
                            isCaptain: member.playerId == userID
                        )
                    }
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Saved locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func canCurrentUserEditTournament(_ tournament: Tournament) -> Bool {
        AccessPolicy.canEditTournament(currentUser, tournament)
    }

    func canCurrentUserManageTournamentTeams(_ tournament: Tournament) -> Bool {
        AccessPolicy.canManageTournamentTeams(currentUser, tournament)
    }

    func canCurrentUserCreateTournamentMatch(_ tournament: Tournament) -> Bool {
        AccessPolicy.canCreateTournamentMatch(currentUser, tournament)
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
        let updatedTournament = tournaments[index]
        tournamentActionMessage = "Tournament details updated."
        AuditLogger.log(action: "tournament_updated", actorId: currentUser?.id, objectId: tournamentID)

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateTournamentDetails(
                        tournamentID: tournamentID,
                        title: updatedTournament.title,
                        location: updatedTournament.location,
                        startDate: updatedTournament.startDate,
                        format: updatedTournament.format,
                        maxTeams: updatedTournament.maxTeams
                    )
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Updated locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func addTeamToTournament(tournamentID: UUID, teamName: String) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }
        guard AccessPolicy.canManageTournamentTeams(currentUser, tournaments[index]) else {
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
        tournaments[index].teamEntries.append(
            TournamentTeam(
                id: team.id,
                tournamentId: tournamentID,
                name: team.name,
                colorHex: "#2D6CC4",
                createdAt: Date()
            )
        )
        tournamentActionMessage = "Team added."
        AuditLogger.log(action: "tournament_team_added", actorId: currentUser?.id, objectId: tournamentID, metadata: ["teamName": trimmedName])

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.createTournamentTeam(tournamentID: tournamentID, team: team)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Added locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func removeTeamFromTournament(tournamentID: UUID, teamID: UUID) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }
        guard AccessPolicy.canManageTournamentTeams(currentUser, tournaments[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        tournaments[index].teams.removeAll { $0.id == teamID }
        tournaments[index].teamEntries.removeAll { $0.id == teamID }
        tournaments[index].teamMembers.removeAll { $0.teamId == teamID }
        tournaments[index].matches.removeAll { $0.homeTeamId == teamID || $0.awayTeamId == teamID }
        tournamentActionMessage = "Team removed."
        AuditLogger.log(action: "tournament_team_removed", actorId: currentUser?.id, objectId: tournamentID, metadata: ["teamId": teamID.uuidString])

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.deleteTournamentTeam(teamID: teamID)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Removed locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func createTournamentMatch(
        tournamentID: UUID,
        homeTeamID: UUID,
        awayTeamID: UUID,
        startTime: Date,
        locationName: String,
        matchday: Int?
    ) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }
        guard AccessPolicy.canCreateTournamentMatch(currentUser, tournaments[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard homeTeamID != awayTeamID else {
            tournamentActionMessage = "Home and away team must be different."
            return
        }
        let duplicateOnMatchday = tournaments[index].matches.contains {
            $0.matchday == matchday && (($0.homeTeamId == homeTeamID && $0.awayTeamId == awayTeamID) || ($0.homeTeamId == awayTeamID && $0.awayTeamId == homeTeamID))
        }
        guard !duplicateOnMatchday else {
            tournamentActionMessage = "Fixture already exists for this matchday."
            return
        }

        let match = TournamentMatch(
            tournamentId: tournamentID,
            homeTeamId: homeTeamID,
            awayTeamId: awayTeamID,
            startTime: startTime,
            locationName: locationName,
            matchday: matchday,
            status: .scheduled
        )
        tournaments[index].matches.append(match)
        tournaments[index].matches.sort { $0.startTime < $1.startTime }
        upsertCreatedGameFromTournamentMatch(tournament: tournaments[index], match: match)
        tournamentActionMessage = "Tournament match scheduled."
        AuditLogger.log(action: "tournament_match_scheduled", actorId: currentUser?.id, objectId: tournamentID, metadata: ["matchId": match.id.uuidString])

        if let supabaseDataService {
            let tournament = tournaments[index]
            Task {
                do {
                    let backendMatch = try await supabaseDataService.createTournamentMatch(
                        tournamentID: tournamentID,
                        ownerID: tournament.ownerId,
                        organiserIDs: tournament.organiserIds,
                        homeTeamID: homeTeamID,
                        awayTeamID: awayTeamID,
                        startTime: startTime,
                        locationName: locationName,
                        format: tournament.format,
                        matchday: matchday
                    )

                    await MainActor.run {
                        if let tournamentIndex = tournaments.firstIndex(where: { $0.id == tournamentID }),
                           let localMatchIndex = tournaments[tournamentIndex].matches.firstIndex(where: { $0.id == match.id }) {
                            tournaments[tournamentIndex].matches[localMatchIndex] = backendMatch
                            upsertCreatedGameFromTournamentMatch(tournament: tournaments[tournamentIndex], match: backendMatch)
                        }
                    }
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Scheduled locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func updateTournamentMatchResult(
        tournamentID: UUID,
        matchID: UUID,
        homeScore: Int,
        awayScore: Int,
        reason: String? = nil
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
        if tournaments[index].matches[matchIndex].status == .completed,
           (reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
            tournamentActionMessage = "Reason is required to edit a completed result."
            return
        }

        tournaments[index].matches[matchIndex].homeScore = max(homeScore, 0)
        tournaments[index].matches[matchIndex].awayScore = max(awayScore, 0)
        tournaments[index].matches[matchIndex].status = .completed
        syncCreatedGameCompletion(matchID: matchID, homeScore: homeScore, awayScore: awayScore)
        tournamentActionMessage = "Tournament result saved."
        var metadata: [String: String] = ["matchId": matchID.uuidString, "home": "\(homeScore)", "away": "\(awayScore)"]
        if let reason = reason?.trimmingCharacters(in: .whitespacesAndNewlines), !reason.isEmpty {
            metadata["reason"] = reason
        }
        AuditLogger.log(action: "tournament_result_updated", actorId: currentUser?.id, objectId: tournamentID, metadata: metadata)

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateTournamentMatchResult(
                        matchID: matchID,
                        homeScore: max(homeScore, 0),
                        awayScore: max(awayScore, 0),
                        reason: reason
                    )
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Saved locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
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

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateTournamentDispute(tournamentID: tournamentID, status: status)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Updated locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func completeTournament(tournamentID: UUID) {
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return
        }
        guard AccessPolicy.canEditTournament(currentUser, tournaments[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        tournaments[index].status = .completed
        for matchIndex in tournaments[index].matches.indices where tournaments[index].matches[matchIndex].status == .scheduled {
            tournaments[index].matches[matchIndex].status = .cancelled
        }
        syncTournamentMatchesToCreatedGames(tournamentID: tournamentID)
        tournamentActionMessage = "Tournament marked as completed."
        AuditLogger.log(action: "tournament_completed", actorId: currentUser?.id, objectId: tournamentID)

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateTournamentStatus(tournamentID: tournamentID, status: .completed)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Completed locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
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
        } else {
            user.losses += 1
        }

        currentUser = user

        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
        }

        if let supabaseDataService {
            Task {
                try? await supabaseDataService.updateUserStats(
                    userID: user.id,
                    eloRating: user.eloRating,
                    matchesPlayed: user.matchesPlayed,
                    wins: user.wins,
                    draws: user.draws,
                    losses: user.losses
                )
            }
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
        if !player.avatarURL.isEmpty {
            updatedUser.avatarURL = player.avatarURL
        }
        updatedUser.preferredPositions = player.preferredPositions

        if let mainPosition = player.positions.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            updatedUser.favoritePosition = mainPosition
        } else if let firstPreferred = player.preferredPositions.first {
            updatedUser.favoritePosition = firstPreferred.rawValue
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
            organiserIds: [currentUser?.id ?? UUID()],
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
            status: .scheduled,
            isDraft: draft.isDraft,
            finalHomeScore: nil,
            finalAwayScore: nil,
            isDeleted: false,
            deletedAt: nil
        )

        createdGames.append(game)
        createdGames.sort { $0.scheduledDate < $1.scheduledDate }

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.createMatch(game: game)
                } catch {
                    await MainActor.run {
                        authErrorMessage = "Game saved locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }

        return .success(game)
    }

    func createTournament(from draft: TournamentDraft, now: Date = Date()) -> Result<Tournament, CreateTournamentValidationError> {
        guard canCurrentUserCreateTournamentFromCreateTab, let user = currentUser else {
            return .failure(.unauthorized)
        }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return .failure(.missingTitle)
        }

        let location = draft.location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else {
            return .failure(.missingLocation)
        }

        guard draft.startAt > now else {
            return .failure(.startAtMustBeFuture)
        }

        if draft.hasEndDate {
            guard draft.endAt >= draft.startAt else {
                return .failure(.endBeforeStart)
            }
        }

        guard draft.maxTeams >= 4 else {
            return .failure(.maxTeamsTooLow)
        }

        let tournament = Tournament(
            id: UUID(),
            title: title,
            location: location,
            startDate: draft.startAt,
            teams: [],
            entryFee: max(draft.entryFee, 0),
            maxTeams: draft.maxTeams,
            format: draft.format.rawValue,
            visibility: draft.visibility,
            status: draft.status,
            ownerId: user.id,
            organiserIds: [user.id],
            endDate: draft.hasEndDate ? draft.endAt : nil,
            teamEntries: [],
            teamMembers: [],
            matches: [],
            disputeStatus: .none,
            isDeleted: false,
            deletedAt: nil
        )

        tournaments.append(tournament)
        tournaments.sort { $0.startDate < $1.startDate }
        tournamentActionMessage = "Tournament created."
        AuditLogger.log(action: "tournament_created", actorId: currentUser?.id, objectId: tournament.id)

        if let supabaseDataService {
            if isUsingSupabase, authenticatedSupabaseUserID != nil, authenticatedSupabaseUserID != user.id {
                tournamentActionMessage = "Tournament saved locally. Backend sync is disabled for switched debug users. Sign in as this account to sync."
                return .success(tournament)
            }
            Task {
                do {
                    let backendTournament = try await supabaseDataService.createTournament(
                        title: title,
                        location: location,
                        startDate: draft.startAt,
                        endDate: draft.hasEndDate ? draft.endAt : nil,
                        visibility: draft.visibility,
                        status: draft.status,
                        entryFee: max(draft.entryFee, 0),
                        maxTeams: draft.maxTeams,
                        format: draft.format.rawValue,
                        ownerID: user.id,
                        organiserIDs: [user.id]
                    )

                    await MainActor.run {
                        if let index = tournaments.firstIndex(where: { $0.id == tournament.id }) {
                            tournaments[index] = backendTournament
                        }
                    }
                } catch {
                    await MainActor.run {
                        if error.localizedDescription.localizedCaseInsensitiveContains("row-level security") {
                            tournamentActionMessage = "Tournament created locally, but backend denied write (RLS). Please sign in with the same account you're using in the app."
                        } else {
                            tournamentActionMessage = "Tournament created locally, but backend sync failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }

        return .success(tournament)
    }

    func updateGameDraft(gameID: UUID, draft: GameDraft, now: Date = Date()) -> Result<CreatedGame, CreateGameValidationError> {
        guard let currentUser else { return .failure(.unauthorized) }
        guard let index = createdGames.firstIndex(where: { $0.id == gameID }) else {
            return .failure(.unauthorized)
        }
        guard createdGames[index].ownerId == currentUser.id || currentUser.isAdmin else {
            return .failure(.unauthorized)
        }
        guard draft.startAt > now else {
            return .failure(.startAtMustBeFuture)
        }
        guard draft.maxPlayers >= draft.format.requiredPlayers else {
            return .failure(.maxPlayersTooLow(minimum: draft.format.requiredPlayers))
        }

        var updated = createdGames[index]
        let inviteLink = draft.isPrivateGame ? (updated.inviteLink ?? "https://sportapp.local/invite/\(UUID().uuidString.lowercased())") : nil
        updated = CreatedGame(
            id: updated.id,
            ownerId: updated.ownerId,
            organiserIds: updated.organiserIds,
            clubLocation: draft.clubLocation,
            startAt: draft.startAt,
            durationMinutes: draft.durationMinutes,
            format: draft.format,
            locationName: draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? draft.clubLocation.rawValue : draft.locationName.trimmingCharacters(in: .whitespacesAndNewlines),
            address: draft.address.trimmingCharacters(in: .whitespacesAndNewlines),
            maxPlayers: draft.maxPlayers,
            isPrivateGame: draft.isPrivateGame,
            hasCourtBooked: draft.hasCourtBooked,
            minElo: min(draft.minElo, draft.maxElo),
            maxElo: max(draft.minElo, draft.maxElo),
            iAmPlaying: draft.iAmPlaying,
            isRatingGame: draft.isRatingGame,
            anyoneCanInvite: draft.anyoneCanInvite,
            anyPlayerCanInputResults: draft.anyPlayerCanInputResults,
            entranceWithoutConfirmation: draft.entranceWithoutConfirmation,
            notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdBy: updated.createdBy,
            inviteLink: inviteLink,
            players: updated.players,
            status: updated.status,
            isDraft: draft.isDraft,
            finalHomeScore: updated.finalHomeScore,
            finalAwayScore: updated.finalAwayScore,
            isDeleted: updated.isDeleted,
            deletedAt: updated.deletedAt
        )

        createdGames[index] = updated
        createdGames.sort { $0.startAt < $1.startAt }

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateCreatedGame(updated)
                } catch {
                    await MainActor.run {
                        authErrorMessage = "Draft updated locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }

        return .success(updated)
    }

    func updateTournamentDraft(tournamentID: UUID, draft: TournamentDraft, now: Date = Date()) -> Result<Tournament, CreateTournamentValidationError> {
        guard canCurrentUserCreateTournamentFromCreateTab, let user = currentUser else {
            return .failure(.unauthorized)
        }
        guard let index = tournaments.firstIndex(where: { $0.id == tournamentID }) else {
            return .failure(.unauthorized)
        }
        let existing = tournaments[index]
        guard existing.ownerId == user.id || existing.organiserIds.contains(user.id) || user.isAdmin else {
            return .failure(.unauthorized)
        }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return .failure(.missingTitle) }
        let location = draft.location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else { return .failure(.missingLocation) }
        guard draft.startAt > now else { return .failure(.startAtMustBeFuture) }
        if draft.hasEndDate, draft.endAt < draft.startAt {
            return .failure(.endBeforeStart)
        }
        guard draft.maxTeams >= 4 else { return .failure(.maxTeamsTooLow) }

        tournaments[index].title = title
        tournaments[index].location = location
        tournaments[index].startDate = draft.startAt
        tournaments[index].endDate = draft.hasEndDate ? draft.endAt : nil
        tournaments[index].visibility = draft.visibility
        tournaments[index].status = draft.status
        tournaments[index].entryFee = max(draft.entryFee, 0)
        tournaments[index].maxTeams = draft.maxTeams
        tournaments[index].format = draft.format.rawValue

        let updated = tournaments[index]
        tournaments.sort { $0.startDate < $1.startDate }

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateTournamentDraft(updated)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Tournament draft updated locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }

        return .success(updated)
    }

    func updatePracticeDraft(sessionID: UUID, draft: PracticeDraft, now: Date = Date()) -> Result<PracticeSession, CreatePracticeValidationError> {
        guard AccessPolicy.canCreateCoachSession(currentUser) else {
            return .failure(.unauthorized)
        }
        guard let index = practices.firstIndex(where: { $0.id == sessionID }) else {
            return .failure(.unauthorized)
        }
        guard canCurrentUserEditPractice(practices[index]) else {
            return .failure(.unauthorized)
        }
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return .failure(.missingTitle) }
        let location = draft.location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else { return .failure(.missingLocation) }
        guard draft.startAt > now else { return .failure(.startAtMustBeFuture) }
        guard (2...60).contains(draft.numberOfPlayers) else { return .failure(.invalidCapacity) }

        practices[index].title = title
        practices[index].location = location
        practices[index].startDate = draft.startAt
        practices[index].durationMinutes = draft.durationMinutes
        practices[index].numberOfPlayers = draft.numberOfPlayers
        practices[index].minElo = min(draft.minElo, draft.maxElo)
        practices[index].maxElo = max(draft.minElo, draft.maxElo)
        practices[index].isOpenJoin = draft.isOpenJoin
        practices[index].focusArea = draft.focusArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : draft.focusArea.trimmingCharacters(in: .whitespacesAndNewlines)
        practices[index].notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        practices[index].isDraft = draft.isDraft

        let updated = practices[index]
        practices.sort { $0.startDate < $1.startDate }

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updatePractice(session: updated)
                } catch {
                    await MainActor.run {
                        authErrorMessage = "Practice draft updated locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }

        return .success(updated)
    }

    func canCurrentUserEditPractice(_ session: PracticeSession) -> Bool {
        let owner = session.ownerId ?? UUID()
        return AccessPolicy.canEditCoachSession(
            currentUser,
            CoachSessionAccessTarget(ownerId: owner, organiserIds: session.organiserIds)
        )
    }

    func createPractice(from draft: PracticeDraft, now: Date = Date()) -> Result<PracticeSession, CreatePracticeValidationError> {
        guard AccessPolicy.canCreateCoachSession(currentUser), let user = currentUser else {
            return .failure(.unauthorized)
        }

        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return .failure(.missingTitle) }
        let location = draft.location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else { return .failure(.missingLocation) }
        guard draft.startAt > now else { return .failure(.startAtMustBeFuture) }
        guard (2...60).contains(draft.numberOfPlayers) else { return .failure(.invalidCapacity) }

        let practice = PracticeSession(
            id: UUID(),
            title: title,
            location: location,
            startDate: draft.startAt,
            durationMinutes: draft.durationMinutes,
            numberOfPlayers: draft.numberOfPlayers,
            minElo: min(draft.minElo, draft.maxElo),
            maxElo: max(draft.minElo, draft.maxElo),
            isOpenJoin: draft.isOpenJoin,
            focusArea: draft.focusArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "General" : draft.focusArea.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines),
            ownerId: user.id,
            organiserIds: [user.id],
            isDraft: draft.isDraft,
            isDeleted: false,
            deletedAt: nil
        )

        practices.append(practice)
        practices.sort { $0.startDate < $1.startDate }

        if let supabaseDataService {
            Task {
                do {
                    let backend = try await supabaseDataService.createPractice(session: practice)
                    await MainActor.run {
                        if let index = practices.firstIndex(where: { $0.id == practice.id }) {
                            practices[index] = backend
                        }
                    }
                } catch {
                    await MainActor.run {
                        authErrorMessage = "Practice created locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }

        return .success(practice)
    }

    func updatePractice(_ session: PracticeSession) {
        guard let index = practices.firstIndex(where: { $0.id == session.id }) else { return }
        guard canCurrentUserEditPractice(practices[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        if !practices[index].isDraft && isPracticeFinished(practices[index]) {
            tournamentActionMessage = "Practice is finished. Editing is locked."
            return
        }
        practices[index] = session
        tournamentActionMessage = "Practice details updated."

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updatePractice(session: session)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Practice updated locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func deletePractice(_ sessionID: UUID) {
        guard let index = practices.firstIndex(where: { $0.id == sessionID }) else { return }
        guard canCurrentUserEditPractice(practices[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        practices[index].isDeleted = true
        practices[index].deletedAt = Date()
        joinedPracticeIDs.remove(sessionID)
        tournamentActionMessage = "Practice deleted."

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.softDeletePractice(sessionID: sessionID)
                } catch {
                    await MainActor.run {
                        authErrorMessage = "Practice deleted locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func endPractice(_ sessionID: UUID) {
        guard let index = practices.firstIndex(where: { $0.id == sessionID }) else { return }
        guard canCurrentUserEditPractice(practices[index]) else {
            tournamentActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        if isPracticeFinished(practices[index]) {
            tournamentActionMessage = "Practice is already finished."
            return
        }

        let durationSeconds = TimeInterval(max(practices[index].durationMinutes, 1) * 60)
        practices[index].startDate = Date().addingTimeInterval(-durationSeconds - 60)
        practices[index].isDraft = false
        let updated = practices[index]
        practices.sort { $0.startDate < $1.startDate }
        tournamentActionMessage = "Practice ended."

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updatePractice(session: updated)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Practice ended locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func reviews(for coachID: UUID) -> [CoachReview] {
        (coachReviewsByCoach[coachID] ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    func hasCurrentUserReviewedPractice(_ practiceID: UUID) -> Bool {
        guard let authorID = currentUser?.id else { return false }
        guard let practice = practices.first(where: { $0.id == practiceID }) else { return false }
        let coachID = practice.ownerId
        return coachReviewsByCoach.values.joined().contains { review in
            guard review.authorID == authorID else { return false }
            if review.practiceID == practiceID {
                return true
            }
            // Backward compatibility for legacy rows created before practice_id existed.
            if review.practiceID == nil, let coachID, review.coachID == coachID {
                return true
            }
            return false
        }
    }

    func canCurrentUserReviewPractice(_ practice: PracticeSession) -> Bool {
        guard let currentUser else { return false }
        guard currentUser.globalRole == .player else { return false }
        guard isPracticeFinished(practice) else { return false }
        guard let coachID = practice.ownerId else { return false }
        guard coachID != currentUser.id else { return false }
        guard joinedPracticeIDs.contains(practice.id) else { return false }
        guard !hasCurrentUserReviewedPractice(practice.id) else { return false }
        return users.first(where: { $0.id == coachID })?.isCoachActive == true
    }

    func addReview(to coachID: UUID, practiceID: UUID?, rating: Int, text: String) {
        guard let author = currentUser else { return }
        guard let coach = users.first(where: { $0.id == coachID }), coach.isCoachActive else { return }
        guard author.id != coachID else { return }
        if let practiceID {
            guard let practice = practices.first(where: { $0.id == practiceID }) else { return }
            guard canCurrentUserReviewPractice(practice) else {
                tournamentActionMessage = "You can leave one review only after attending a finished practice."
                return
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let review = CoachReview(
            id: UUID(),
            coachID: coachID,
            practiceID: practiceID,
            authorID: author.id,
            authorName: author.fullName,
            rating: min(max(rating, 1), 5),
            text: trimmed,
            createdAt: Date()
        )
        coachReviewsByCoach[coachID, default: []].append(review)
        tournamentActionMessage = "Review submitted."

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.addCoachReview(review)
                } catch {
                    await MainActor.run {
                        tournamentActionMessage = "Review saved locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
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

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateUserRole(userID: userId, role: role)
                } catch {
                    await MainActor.run {
                        adminActionMessage = "Role updated locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
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

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.setUserSuspended(
                        userID: userId,
                        isSuspended: isSuspended,
                        reason: users[index].suspensionReason
                    )
                } catch {
                    await MainActor.run {
                        adminActionMessage = "Suspension updated locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func adminSetOrganizerAccess(userId: UUID, isActive: Bool) {
        guard AccessPolicy.canManageUsersAsAdmin(currentUser) else {
            adminActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let index = users.firstIndex(where: { $0.id == userId }) else {
            return
        }

        let newEndsAt: Date? = isActive ? Calendar.current.date(byAdding: .day, value: 30, to: Date()) : nil
        users[index].organizerSubscriptionEndsAt = newEndsAt
        users[index].isOrganizerSubscriptionPaused = false

        if currentUser?.id == userId {
            currentUser = users[index]
        }

        adminActionMessage = isActive ? "Organizer access granted for 30 days." : "Organizer access revoked."
        AuditLogger.log(
            action: isActive ? "admin_organizer_subscription_granted" : "admin_organizer_subscription_revoked",
            actorId: currentUser?.id,
            objectId: userId,
            metadata: ["ends_at": newEndsAt?.description ?? ""]
        )

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.setOrganizerSubscription(
                        userID: userId,
                        endsAt: newEndsAt,
                        isPaused: false
                    )
                } catch {
                    await MainActor.run {
                        adminActionMessage = "Organizer access updated locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func adminPrepareInvestorDemoData() {
        guard AccessPolicy.canManageUsersAsAdmin(currentUser) else {
            adminActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let currentUser else {
            adminActionMessage = "No active admin user."
            return
        }

        func prepareLocalOnly(message: String) {
            let demo = buildInvestorDemoData()
            users = demo.users
            tournaments = demo.tournaments
            createdGames = demo.games
            practices = demo.practices
            coachReviewsByCoach = demo.coachReviewsByCoach
            clubs = demo.clubs
            refreshGameLists()
            adminActionMessage = message
            AuditLogger.log(
                action: "admin_investor_demo_seeded_local",
                actorId: currentUser.id,
                objectId: currentUser.id
            )
        }

        if isUsingSupabase, authenticatedSupabaseUserID != nil, authenticatedSupabaseUserID != currentUser.id {
            prepareLocalOnly(message: "Investor demo prepared locally. To write shared demo data to DB, sign in with a real Supabase admin (not Debug Switch User).")
            return
        }

        guard let supabaseDataService else {
            prepareLocalOnly(message: "Investor demo prepared locally (Supabase not configured).")
            return
        }

        Task {
            do {
                let reviewWriteSucceeded = try await prepareInvestorDemoDataInBackend(
                    actor: currentUser,
                    dataService: supabaseDataService
                )
                try await syncFromBackend(currentUserID: currentUser.id)
                await MainActor.run {
                    adminActionMessage = reviewWriteSucceeded
                        ? "Investor demo data prepared and synced to DB."
                        : "Investor demo data prepared and synced to DB (coach review insert skipped by policy)."
                }
                AuditLogger.log(
                    action: "admin_investor_demo_seeded",
                    actorId: currentUser.id,
                    objectId: currentUser.id
                )
            } catch {
                await MainActor.run {
                    adminActionMessage = "Investor demo sync failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func adminSeedSharedDemoDataToBackend() {
        guard AccessPolicy.canManageUsersAsAdmin(currentUser) else {
            adminActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let supabaseDataService else {
            adminActionMessage = "Supabase is not configured."
            return
        }
        guard let currentUser else {
            adminActionMessage = "No active admin user."
            return
        }

        Task {
            do {
                let fetchedUsers = try await supabaseDataService.fetchProfiles()
                let usersByID = Dictionary(fetchedUsers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                let existingGames = try await supabaseDataService.fetchCreatedGames(usersById: usersByID)
                let existingTournaments = try await supabaseDataService.fetchTournaments(usersById: usersByID)
                let existingPractices = try await supabaseDataService.fetchPractices()

                let now = Date()

                let upcomingGamesCount = existingGames.filter {
                    !$0.isDeleted && !$0.isDraft && $0.status == .scheduled && $0.startAt > now
                }.count

                if upcomingGamesCount < 4 {
                    let seedOwner = fetchedUsers.first(where: { $0.isOrganizerActive || $0.isAdmin }) ?? fetchedUsers.first ?? currentUser
                    let seedGames = buildDemoCreatedGames(for: seedOwner, users: fetchedUsers)
                        .filter { $0.status == .scheduled && !$0.isDraft && $0.startAt > now }
                    for game in seedGames {
                        try? await supabaseDataService.createMatch(game: game)
                    }
                }

                let upcomingPracticesCount = existingPractices.filter {
                    !$0.isDeleted && !$0.isDraft && $0.startDate > now
                }.count

                if upcomingPracticesCount < 3 {
                    let coach = fetchedUsers.first(where: { $0.isCoachActive }) ?? currentUser
                    let practiceSeeds: [PracticeSession] = [
                        PracticeSession(
                            id: UUID(),
                            title: "Ball Control & Passing",
                            location: "Downtown Arena",
                            startDate: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now,
                            durationMinutes: 90,
                            numberOfPlayers: 12,
                            minElo: 1000,
                            maxElo: 2000,
                            isOpenJoin: true,
                            focusArea: "Ball control",
                            notes: "Bring light bibs and water.",
                            ownerId: coach.id,
                            organiserIds: [coach.id],
                            isDraft: false,
                            isDeleted: false
                        ),
                        PracticeSession(
                            id: UUID(),
                            title: "Defensive Shape Practice",
                            location: "North Sports Center",
                            startDate: Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now,
                            durationMinutes: 75,
                            numberOfPlayers: 10,
                            minElo: 1100,
                            maxElo: 2100,
                            isOpenJoin: false,
                            focusArea: "Defending",
                            notes: "Focus on transitions and compactness.",
                            ownerId: coach.id,
                            organiserIds: [coach.id],
                            isDraft: false,
                            isDeleted: false
                        ),
                        PracticeSession(
                            id: UUID(),
                            title: "Finishing & Pressing",
                            location: "Riverside Courts",
                            startDate: Calendar.current.date(byAdding: .day, value: 4, to: now) ?? now,
                            durationMinutes: 90,
                            numberOfPlayers: 14,
                            minElo: 900,
                            maxElo: 2200,
                            isOpenJoin: true,
                            focusArea: "Finishing",
                            notes: "High-intensity final third drills.",
                            ownerId: coach.id,
                            organiserIds: [coach.id],
                            isDraft: false,
                            isDeleted: false
                        )
                    ]

                    for session in practiceSeeds {
                        try? await supabaseDataService.createPractice(session: session)
                    }
                }

                let upcomingTournamentsCount = existingTournaments.filter {
                    !$0.isDeleted && $0.startDate > now
                }.count

                if upcomingTournamentsCount < 3 {
                    let owner = fetchedUsers.first(where: { $0.isOrganizerActive || $0.isAdmin }) ?? currentUser
                    try? await supabaseDataService.seedExampleTournament(for: owner, users: fetchedUsers)
                    try? await supabaseDataService.seedExampleTournament(for: owner, users: fetchedUsers)
                }

                try await syncFromBackend(currentUserID: currentUser.id)
                await MainActor.run {
                    adminActionMessage = "Shared upcoming demo data seeded to backend."
                }
            } catch {
                await MainActor.run {
                    adminActionMessage = "Backend seed failed: \(error.localizedDescription)"
                }
            }
        }
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
        createdGames[index].status = .cancelled
        adminActionMessage = "Match deleted (soft)."
        AuditLogger.log(action: "admin_match_deleted", actorId: currentUser?.id, objectId: gameId)
        if let supabaseDataService {
            Task { try? await supabaseDataService.softDeleteMatch(matchID: gameId) }
        }
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
        createdGames[index].status = .cancelled
        AuditLogger.log(action: "match_deleted", actorId: user.id, objectId: gameId)
        if let supabaseDataService {
            Task { try? await supabaseDataService.softDeleteMatch(matchID: gameId) }
        }
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

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.softDeleteTournament(tournamentID: tournamentId)
                } catch {
                    await MainActor.run {
                        adminActionMessage = "Tournament deleted locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
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

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.softDeletePractice(sessionID: sessionId)
                } catch {
                    await MainActor.run {
                        adminActionMessage = "Session deleted locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func adminClearAllPlayableData() {
        guard AccessPolicy.canManageUsersAsAdmin(currentUser) else {
            adminActionMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        let now = Date()
        let gameIDs = createdGames.map(\.id)
        let tournamentIDs = tournaments.map(\.id)
        let practiceIDs = practices.map(\.id)

        for index in createdGames.indices {
            createdGames[index].isDeleted = true
            createdGames[index].deletedAt = now
            createdGames[index].status = .cancelled
        }
        for index in tournaments.indices {
            tournaments[index].isDeleted = true
            tournaments[index].deletedAt = now
        }
        for index in practices.indices {
            practices[index].isDeleted = true
            practices[index].deletedAt = now
        }
        joinedPracticeIDs.removeAll()
        refreshGameLists()
        adminActionMessage = "All games, tournaments and practices were cleared."
        AuditLogger.log(action: "admin_cleared_all_playable_data", actorId: currentUser?.id, objectId: currentUser?.id ?? UUID())

        if let supabaseDataService {
            Task {
                for gameID in gameIDs {
                    try? await supabaseDataService.softDeleteMatch(matchID: gameID)
                }
                for tournamentID in tournamentIDs {
                    try? await supabaseDataService.softDeleteTournament(tournamentID: tournamentID)
                }
                for practiceID in practiceIDs {
                    try? await supabaseDataService.softDeletePractice(sessionID: practiceID)
                }
                await MainActor.run {
                    adminActionMessage = "All games, tournaments and practices were cleared (DB synced)."
                }
            }
        }
    }

    func refreshGameLists() {
        objectWillChange.send()
    }

    func refreshFromBackendIfAvailable() async {
        guard isUsingSupabase, let userId = currentUser?.id else { return }
        do {
            try await syncFromBackend(currentUserID: userId)
        } catch {
            await MainActor.run {
                authErrorMessage = "Failed to refresh backend data: \(error.localizedDescription)"
            }
        }
    }

    func createdGame(for id: UUID) -> CreatedGame? {
        visibleCreatedGames.first(where: { $0.id == id })
    }

    func isCurrentUserGoingInGame(_ gameID: UUID) -> Bool {
        guard let game = createdGames.first(where: { $0.id == gameID }) else { return false }
        return currentUserRSVPStatus(in: game) == .going
    }

    func syncTournamentMatchesToCreatedGames(tournamentID: UUID) {
        guard let tournament = tournaments.first(where: { $0.id == tournamentID }) else { return }
        for match in tournament.matches {
            upsertCreatedGameFromTournamentMatch(tournament: tournament, match: match)
        }
    }

    private func persistedMatchStatus(for matchId: UUID) -> MatchStatus {
        if let persisted = matchStore.load(matchId: matchId)?.status {
            return persisted
        }
        return createdGames.first(where: { $0.id == matchId })?.status ?? .scheduled
    }

    private func persistedMatchStartTime(for matchId: UUID, fallback: Date) -> Date {
        matchStore.load(matchId: matchId)?.startTime ?? fallback
    }

    private func isUserParticipantOrOwner(userId: UUID, in game: CreatedGame) -> Bool {
        game.ownerId == userId || game.players.contains(where: { $0.id == userId })
    }

    private func isUserInTournament(userId: UUID, in tournament: Tournament) -> Bool {
        if tournament.ownerId == userId || tournament.organiserIds.contains(userId) {
            return true
        }
        return tournament.teams.contains { team in
            team.members.contains(where: { $0.id == userId })
        }
    }

    private func isTournamentPast(_ tournament: Tournament) -> Bool {
        if tournament.matches.contains(where: { !$0.isCompleted }) {
            return tournament.startDate < Date()
        }
        if !tournament.matches.isEmpty {
            return true
        }
        return tournament.startDate < Date()
    }

    private func isPracticeFinished(_ practice: PracticeSession) -> Bool {
        let end = practice.startDate.addingTimeInterval(TimeInterval(max(practice.durationMinutes, 0) * 60))
        return end <= Date()
    }

    private func currentUserRSVPStatus(in game: CreatedGame) -> RSVPStatus? {
        guard let userId = currentUser?.id else { return nil }

        if let persistedState = matchStore.load(matchId: game.id),
           let participant = persistedState.participants.first(where: { $0.id == userId }) {
            return participant.rsvpStatus
        }

        if game.ownerId == userId {
            return .going
        }

        return nil
    }

    private func persistCurrentUserRSVP(matchID: UUID, game: CreatedGame, status: RSVPStatus) {
        guard let user = currentUser else { return }
        let participant = Participant(
            id: user.id,
            name: user.fullName,
            teamId: UUID(),
            elo: user.eloRating,
            positionGroup: .bench,
            rsvpStatus: status,
            invitedAt: Date()
        )

        let existingState = matchStore.load(matchId: matchID)
        let state = MatchLocalState(
            participants: [participant],
            events: existingState?.events ?? [],
            location: existingState?.location ?? game.locationName,
            startTime: existingState?.startTime ?? game.startAt,
            format: existingState?.format ?? game.format.rawValue,
            notes: existingState?.notes ?? game.notes,
            maxPlayers: existingState?.maxPlayers ?? game.maxPlayers,
            status: existingState?.status ?? .scheduled,
            finalHomeScore: existingState?.finalHomeScore,
            finalAwayScore: existingState?.finalAwayScore,
            isDeleted: existingState?.isDeleted ?? false
        )
        matchStore.save(matchId: matchID, state: state)
        refreshGameLists()
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
            organiserIds: tournament.organiserIds,
            clubLocation: .cityFiveLeagueHub,
            startAt: match.startTime,
            durationMinutes: 90,
            format: format,
            locationName: match.locationName ?? tournament.location,
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
            status: match.status == .completed ? .completed : (match.status == .cancelled ? .cancelled : .scheduled),
            isDraft: false,
            finalHomeScore: match.homeScore,
            finalAwayScore: match.awayScore,
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
        if let index = createdGames.firstIndex(where: { $0.id == matchID }) {
            createdGames[index].status = .completed
            createdGames[index].finalHomeScore = homeScore
            createdGames[index].finalAwayScore = awayScore
        }
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

    private struct InvestorDemoData {
        let users: [User]
        let tournaments: [Tournament]
        let games: [CreatedGame]
        let practices: [PracticeSession]
        let coachReviewsByCoach: [UUID: [CoachReview]]
        let clubs: [Club]
    }

    private func prepareInvestorDemoDataInBackend(
        actor: User,
        dataService: SupabaseDataService
    ) async throws -> Bool {
        var fetchedUsers = try await dataService.fetchProfiles()
        if fetchedUsers.isEmpty {
            throw NSError(
                domain: "AppViewModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No profiles found in DB. Register a few users first."]
            )
        }

        let now = Date()
        let plusDays: (Int) -> Date = { Calendar.current.date(byAdding: .day, value: $0, to: now) ?? now }
        let plusHours: (Int) -> Date = { Calendar.current.date(byAdding: .hour, value: $0, to: now) ?? now }

        func updateCachedUser(_ updated: User) {
            if let index = fetchedUsers.firstIndex(where: { $0.id == updated.id }) {
                fetchedUsers[index] = updated
            }
        }

        guard var organizer = fetchedUsers.first(where: { !$0.isSuspended && $0.id != actor.id && !$0.isAdmin }) ?? fetchedUsers.first(where: { !$0.isSuspended }) else {
            throw NSError(domain: "AppViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "No active users available for demo seed."])
        }

        if !organizer.isOrganizerActive {
            let organizerEndsAt = Calendar.current.date(byAdding: .day, value: 30, to: now)
            try await dataService.setOrganizerSubscription(userID: organizer.id, endsAt: organizerEndsAt, isPaused: false)
            organizer.organizerSubscriptionEndsAt = organizerEndsAt
            organizer.isOrganizerSubscriptionPaused = false
            updateCachedUser(organizer)
        }

        var coach = fetchedUsers.first(where: { !$0.isSuspended && $0.id != organizer.id && !$0.isAdmin }) ?? organizer
        if !coach.isCoachActive {
            let coachEndsAt = Calendar.current.date(byAdding: .day, value: 30, to: now)
            try await dataService.setCoachSubscription(userID: coach.id, endsAt: coachEndsAt, isPaused: false)
            coach.coachSubscriptionEndsAt = coachEndsAt
            coach.isCoachSubscriptionPaused = false
            updateCachedUser(coach)
        }

        let usableUsers = dedupeUsersById(fetchedUsers.filter { !$0.isSuspended })
        let players = usableUsers.filter { $0.id != organizer.id && $0.id != coach.id && $0.id != actor.id }
        let p1 = players.indices.contains(0) ? players[0] : organizer
        let p2 = players.indices.contains(1) ? players[1] : coach
        let p3 = players.indices.contains(2) ? players[2] : actor
        let p4 = players.indices.contains(3) ? players[3] : p1

        let usersByID = Dictionary(usableUsers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let existingGames = try await dataService.fetchCreatedGames(usersById: usersByID)
        let existingTournaments = try await dataService.fetchTournaments(usersById: usersByID)
        let existingPractices = try await dataService.fetchPractices()

        for game in existingGames where !game.isDeleted {
            try? await dataService.softDeleteMatch(matchID: game.id)
        }
        for tournament in existingTournaments where !tournament.isDeleted {
            try? await dataService.softDeleteTournament(tournamentID: tournament.id)
        }
        for session in existingPractices where !session.isDeleted {
            try? await dataService.softDeletePractice(sessionID: session.id)
        }

        let quickBookingGame = CreatedGame(
            id: UUID(),
            ownerId: actor.id,
            organiserIds: [actor.id],
            clubLocation: .downtownArena,
            startAt: plusHours(6),
            durationMinutes: 90,
            format: .fiveVFive,
            locationName: "Downtown Arena",
            address: "Austin, TX",
            maxPlayers: 10,
            isPrivateGame: false,
            hasCourtBooked: true,
            minElo: 1000,
            maxElo: 2500,
            iAmPlaying: false,
            isRatingGame: true,
            anyoneCanInvite: true,
            anyPlayerCanInputResults: false,
            entranceWithoutConfirmation: false,
            notes: "Investor demo quick booking",
            createdBy: actor.fullName,
            inviteLink: nil,
            players: [actor, organizer, p1, p2, p3],
            status: .scheduled,
            isDraft: false,
            finalHomeScore: nil,
            finalAwayScore: nil,
            isDeleted: false,
            deletedAt: nil
        )

        let upcomingGame = CreatedGame(
            id: UUID(),
            ownerId: actor.id,
            organiserIds: [actor.id],
            clubLocation: .northSportsCenter,
            startAt: plusDays(1),
            durationMinutes: 90,
            format: .fiveVFive,
            locationName: "North Sports Center",
            address: "Dallas, TX",
            maxPlayers: 10,
            isPrivateGame: false,
            hasCourtBooked: false,
            minElo: 900,
            maxElo: 2200,
            iAmPlaying: false,
            isRatingGame: true,
            anyoneCanInvite: true,
            anyPlayerCanInputResults: false,
            entranceWithoutConfirmation: true,
            notes: "Investor demo upcoming game",
            createdBy: actor.fullName,
            inviteLink: nil,
            players: [actor, p1, p2, p4],
            status: .scheduled,
            isDraft: false,
            finalHomeScore: nil,
            finalAwayScore: nil,
            isDeleted: false,
            deletedAt: nil
        )

        let completedGame = CreatedGame(
            id: UUID(),
            ownerId: actor.id,
            organiserIds: [actor.id],
            clubLocation: .riversideCourts,
            startAt: plusDays(-2),
            durationMinutes: 90,
            format: .fiveVFive,
            locationName: "Riverside Courts",
            address: "Houston, TX",
            maxPlayers: 10,
            isPrivateGame: false,
            hasCourtBooked: true,
            minElo: 900,
            maxElo: 2400,
            iAmPlaying: false,
            isRatingGame: true,
            anyoneCanInvite: false,
            anyPlayerCanInputResults: false,
            entranceWithoutConfirmation: false,
            notes: "Investor demo completed game",
            createdBy: actor.fullName,
            inviteLink: nil,
            players: [actor, organizer, p1, p2, p3, p4],
            status: .scheduled,
            isDraft: false,
            finalHomeScore: nil,
            finalAwayScore: nil,
            isDeleted: false,
            deletedAt: nil
        )

        for game in [quickBookingGame, upcomingGame, completedGame] {
            try await dataService.createMatch(game: game)
        }
        try await dataService.completeMatchAndApplyElo(matchID: completedGame.id, homeScore: 4, awayScore: 2)

        let upcomingPractice = PracticeSession(
            id: UUID(),
            title: "Ball Control Practice",
            location: "Downtown Arena",
            startDate: plusDays(2),
            durationMinutes: 90,
            numberOfPlayers: 12,
            minElo: 900,
            maxElo: 2200,
            isOpenJoin: true,
            focusArea: "Ball control",
            notes: "Bring water and light bibs.",
            ownerId: coach.id,
            organiserIds: [coach.id],
            isDraft: false,
            isDeleted: false
        )
        let completedPractice = PracticeSession(
            id: UUID(),
            title: "Defensive Shape Practice",
            location: "North Sports Center",
            startDate: plusDays(-1),
            durationMinutes: 75,
            numberOfPlayers: 10,
            minElo: 1000,
            maxElo: 2300,
            isOpenJoin: true,
            focusArea: "Defending",
            notes: "Completed practice for demo reviews.",
            ownerId: coach.id,
            organiserIds: [coach.id],
            isDraft: false,
            isDeleted: false
        )
        _ = try await dataService.createPractice(session: upcomingPractice)
        _ = try await dataService.createPractice(session: completedPractice)

        let upcomingTournament = try await dataService.createTournament(
            title: "Investor Cup Upcoming",
            location: "Austin",
            startDate: plusDays(3),
            endDate: plusDays(6),
            visibility: .public,
            status: .published,
            entryFee: 25,
            maxTeams: 8,
            format: MatchFormat.fiveVFive.rawValue,
            ownerID: actor.id,
            organiserIDs: [actor.id]
        )

        let pastTournament = try await dataService.createTournament(
            title: "Investor Cup Past",
            location: "Dallas",
            startDate: plusDays(-5),
            endDate: plusDays(-2),
            visibility: .public,
            status: .completed,
            entryFee: 15,
            maxTeams: 8,
            format: MatchFormat.fiveVFive.rawValue,
            ownerID: actor.id,
            organiserIDs: [actor.id]
        )

        let allTeamUsers = [p1, p2, p3, p4, actor, coach, organizer]
        let teamNames = ["Falcons", "Titans", "Wolves", "Comets"]

        func createTournamentSet(_ tournament: Tournament) async throws -> [Team] {
            var teams: [Team] = []
            for name in teamNames {
                let team = Team(id: UUID(), name: name, members: [], maxPlayers: 6)
                try await dataService.createTournamentTeam(tournamentID: tournament.id, team: team)
                teams.append(team)
            }

            for (index, user) in allTeamUsers.enumerated() {
                let targetTeam = teams[index % teams.count]
                try? await dataService.addTournamentTeamMember(
                    tournamentID: tournament.id,
                    teamID: targetTeam.id,
                    userID: user.id,
                    positionGroup: .bench,
                    sortOrder: index,
                    isCaptain: index < teams.count
                )
            }
            return teams
        }

        let upcomingTeams = try await createTournamentSet(upcomingTournament)
        _ = try await dataService.createTournamentMatch(
            tournamentID: upcomingTournament.id,
            ownerID: upcomingTournament.ownerId,
            organiserIDs: upcomingTournament.organiserIds,
            homeTeamID: upcomingTeams[0].id,
            awayTeamID: upcomingTeams[1].id,
            startTime: plusDays(3),
            locationName: upcomingTournament.location,
            format: upcomingTournament.format,
            matchday: 1
        )

        let pastTeams = try await createTournamentSet(pastTournament)
        let pastMatch = try await dataService.createTournamentMatch(
            tournamentID: pastTournament.id,
            ownerID: pastTournament.ownerId,
            organiserIDs: pastTournament.organiserIds,
            homeTeamID: pastTeams[0].id,
            awayTeamID: pastTeams[1].id,
            startTime: plusDays(-4),
            locationName: pastTournament.location,
            format: pastTournament.format,
            matchday: 1
        )
        try await dataService.updateTournamentMatchResult(matchID: pastMatch.id, homeScore: 3, awayScore: 1)

        var reviewWriteSucceeded = true
        do {
            try await dataService.addCoachReview(
                CoachReview(
                    id: UUID(),
                    coachID: coach.id,
                    practiceID: completedPractice.id,
                    authorID: actor.id,
                    authorName: actor.fullName,
                    rating: 5,
                    text: "Great session structure and clear feedback.",
                    createdAt: now
                )
            )
        } catch {
            reviewWriteSucceeded = false
        }

        return reviewWriteSucceeded
    }

    private func buildInvestorDemoData() -> InvestorDemoData {
        let now = Date()
        let plus: (Int) -> Date = { Calendar.current.date(byAdding: .day, value: $0, to: now) ?? now }
        let plusHours: (Int) -> Date = { Calendar.current.date(byAdding: .hour, value: $0, to: now) ?? now }

        let admin = User(
            id: UUID(),
            fullName: "Demo Admin",
            email: "demo+admin@local.app",
            favoritePosition: "Midfielder",
            city: "Austin",
            eloRating: 1580,
            matchesPlayed: 40,
            wins: 24,
            draws: 6,
            losses: 10,
            globalRole: .admin
        )

        let organizer = User(
            id: UUID(),
            fullName: "Demo Organizer",
            email: "demo+organizer@local.app",
            favoritePosition: "Defender",
            city: "Dallas",
            eloRating: 1520,
            matchesPlayed: 34,
            wins: 18,
            draws: 7,
            losses: 9,
            globalRole: .player,
            organizerSubscriptionEndsAt: Calendar.current.date(byAdding: .day, value: 60, to: now),
            isOrganizerSubscriptionPaused: false
        )

        let coach = User(
            id: UUID(),
            fullName: "Demo Coach",
            email: "demo+coach@local.app",
            favoritePosition: "Forward",
            city: "Houston",
            eloRating: 1605,
            matchesPlayed: 28,
            wins: 17,
            draws: 5,
            losses: 6,
            globalRole: .player,
            coachSubscriptionEndsAt: Calendar.current.date(byAdding: .day, value: 60, to: now),
            isCoachSubscriptionPaused: false
        )

        let p1 = User(id: UUID(), fullName: "Liam Stone", email: "demo+p1@local.app", favoritePosition: "Goalkeeper", city: "Austin", eloRating: 1450, matchesPlayed: 12, wins: 7, draws: 2, losses: 3, globalRole: .player)
        let p2 = User(id: UUID(), fullName: "Noah Green", email: "demo+p2@local.app", favoritePosition: "Defender", city: "Dallas", eloRating: 1480, matchesPlayed: 15, wins: 8, draws: 3, losses: 4, globalRole: .player)
        let p3 = User(id: UUID(), fullName: "Mia White", email: "demo+p3@local.app", favoritePosition: "Midfielder", city: "Houston", eloRating: 1510, matchesPlayed: 20, wins: 11, draws: 4, losses: 5, globalRole: .player)
        let p4 = User(id: UUID(), fullName: "Emma Black", email: "demo+p4@local.app", favoritePosition: "Forward", city: "Miami", eloRating: 1430, matchesPlayed: 10, wins: 5, draws: 2, losses: 3, globalRole: .player)
        let p5 = User(id: UUID(), fullName: "Ava Hill", email: "demo+p5@local.app", favoritePosition: "Midfielder", city: "Austin", eloRating: 1475, matchesPlayed: 14, wins: 8, draws: 1, losses: 5, globalRole: .player)

        let users = [admin, organizer, coach, p1, p2, p3, p4, p5]

        let games: [CreatedGame] = [
            CreatedGame(
                id: UUID(),
                ownerId: organizer.id,
                organiserIds: [organizer.id],
                clubLocation: .downtownArena,
                startAt: plusHours(4),
                durationMinutes: 90,
                format: .fiveVFive,
                locationName: "Downtown Arena",
                address: "Austin, TX",
                maxPlayers: 10,
                isPrivateGame: false,
                hasCourtBooked: true,
                minElo: 1200,
                maxElo: 1800,
                iAmPlaying: false,
                isRatingGame: true,
                anyoneCanInvite: true,
                anyPlayerCanInputResults: false,
                entranceWithoutConfirmation: false,
                notes: "Investor demo quick booking game",
                createdBy: organizer.fullName,
                inviteLink: "https://sportapp.local/invite/demo-quick",
                players: [organizer, p1, p2, p3],
                status: .scheduled,
                isDraft: false,
                finalHomeScore: nil,
                finalAwayScore: nil,
                isDeleted: false,
                deletedAt: nil
            ),
            CreatedGame(
                id: UUID(),
                ownerId: p1.id,
                organiserIds: [p1.id],
                clubLocation: .northSportsCenter,
                startAt: plus(2),
                durationMinutes: 90,
                format: .fiveVFive,
                locationName: "North Sports Center",
                address: "Dallas, TX",
                maxPlayers: 10,
                isPrivateGame: false,
                hasCourtBooked: false,
                minElo: 1000,
                maxElo: 2000,
                iAmPlaying: true,
                isRatingGame: true,
                anyoneCanInvite: true,
                anyPlayerCanInputResults: false,
                entranceWithoutConfirmation: true,
                notes: "Community evening game",
                createdBy: p1.fullName,
                inviteLink: "https://sportapp.local/invite/demo-upcoming",
                players: [p1, p4, p5],
                status: .scheduled,
                isDraft: false,
                finalHomeScore: nil,
                finalAwayScore: nil,
                isDeleted: false,
                deletedAt: nil
            ),
            CreatedGame(
                id: UUID(),
                ownerId: organizer.id,
                organiserIds: [organizer.id],
                clubLocation: .riversideCourts,
                startAt: plus(-3),
                durationMinutes: 90,
                format: .fiveVFive,
                locationName: "Riverside Courts",
                address: "Houston, TX",
                maxPlayers: 10,
                isPrivateGame: false,
                hasCourtBooked: true,
                minElo: 1000,
                maxElo: 2200,
                iAmPlaying: true,
                isRatingGame: true,
                anyoneCanInvite: false,
                anyPlayerCanInputResults: false,
                entranceWithoutConfirmation: false,
                notes: "Completed showcase game",
                createdBy: organizer.fullName,
                inviteLink: nil,
                players: [organizer, p2, p3, p4],
                status: .completed,
                isDraft: false,
                finalHomeScore: 4,
                finalAwayScore: 2,
                isDeleted: false,
                deletedAt: nil
            ),
            CreatedGame(
                id: UUID(),
                ownerId: organizer.id,
                organiserIds: [organizer.id],
                clubLocation: .cityFiveLeagueHub,
                startAt: plus(6),
                durationMinutes: 90,
                format: .sevenVSeven,
                locationName: "City Five League Hub",
                address: "Austin, TX",
                maxPlayers: 14,
                isPrivateGame: true,
                hasCourtBooked: false,
                minElo: 1200,
                maxElo: 2000,
                iAmPlaying: true,
                isRatingGame: false,
                anyoneCanInvite: false,
                anyPlayerCanInputResults: false,
                entranceWithoutConfirmation: false,
                notes: "Draft game for later publishing",
                createdBy: organizer.fullName,
                inviteLink: nil,
                players: [organizer, p5],
                status: .scheduled,
                isDraft: true,
                finalHomeScore: nil,
                finalAwayScore: nil,
                isDeleted: false,
                deletedAt: nil
            )
        ]

        let teamA = Team(id: UUID(), name: "Downtown Falcons", members: [p1, p2], maxPlayers: 6)
        let teamB = Team(id: UUID(), name: "North Titans", members: [p3, p4], maxPlayers: 6)
        let teamC = Team(id: UUID(), name: "River Wolves", members: [p5, organizer], maxPlayers: 6)
        let teamD = Team(id: UUID(), name: "City Comets", members: [admin], maxPlayers: 6)
        let teams = [teamA, teamB, teamC, teamD]

        let tournamentId = UUID()
        let teamEntries = teams.map {
            TournamentTeam(id: $0.id, tournamentId: tournamentId, name: $0.name, colorHex: "#2D6CC4", createdAt: now)
        }
        let teamMembers = teams.flatMap { team in
            team.members.enumerated().map { index, member in
                TournamentTeamMember(
                    teamId: team.id,
                    playerId: member.id,
                    positionGroup: .bench,
                    sortOrder: index,
                    isCaptain: index == 0
                )
            }
        }
        let tournamentMatches = [
            TournamentMatch(
                id: UUID(),
                tournamentId: tournamentId,
                homeTeamId: teamA.id,
                awayTeamId: teamB.id,
                startTime: plus(-1),
                locationName: "Downtown Arena",
                matchday: 1,
                homeScore: 2,
                awayScore: 2,
                status: .completed
            ),
            TournamentMatch(
                id: UUID(),
                tournamentId: tournamentId,
                homeTeamId: teamC.id,
                awayTeamId: teamD.id,
                startTime: plus(1),
                locationName: "North Sports Center",
                matchday: 1,
                homeScore: nil,
                awayScore: nil,
                status: .scheduled
            )
        ]

        let tournament = Tournament(
            id: tournamentId,
            title: "Investor League Showcase",
            location: "Austin",
            startDate: plus(-1),
            teams: teams,
            entryFee: 25,
            maxTeams: 8,
            format: MatchFormat.fiveVFive.rawValue,
            visibility: .public,
            status: .published,
            ownerId: organizer.id,
            organiserIds: [organizer.id],
            endDate: plus(7),
            teamEntries: teamEntries,
            teamMembers: teamMembers,
            matches: tournamentMatches,
            disputeStatus: .none,
            isDeleted: false,
            deletedAt: nil
        )

        let tournamentDraft = Tournament(
            id: UUID(),
            title: "Summer Cup Draft",
            location: "Houston",
            startDate: plus(20),
            teams: [],
            entryFee: 35,
            maxTeams: 12,
            format: MatchFormat.sevenVSeven.rawValue,
            visibility: .public,
            status: .draft,
            ownerId: organizer.id,
            organiserIds: [organizer.id],
            endDate: nil,
            teamEntries: [],
            teamMembers: [],
            matches: [],
            disputeStatus: .none,
            isDeleted: false,
            deletedAt: nil
        )

        let practices = [
            PracticeSession(
                id: UUID(),
                title: "Tactical Shape Practice",
                location: "Riverside Courts",
                startDate: plus(2),
                durationMinutes: 90,
                numberOfPlayers: 12,
                minElo: 1100,
                maxElo: 1800,
                isOpenJoin: true,
                focusArea: "Positioning",
                notes: "Bring cones and bibs.",
                ownerId: coach.id,
                organiserIds: [coach.id],
                isDraft: false,
                isDeleted: false
            ),
            PracticeSession(
                id: UUID(),
                title: "Finishing Session Draft",
                location: "Downtown Arena",
                startDate: plus(5),
                durationMinutes: 75,
                numberOfPlayers: 10,
                minElo: 1000,
                maxElo: 2000,
                isOpenJoin: false,
                focusArea: "Finishing",
                notes: "Draft practice",
                ownerId: coach.id,
                organiserIds: [coach.id],
                isDraft: true,
                isDeleted: false
            )
        ]

        let reviewsByCoach: [UUID: [CoachReview]] = [
            coach.id: [
                CoachReview(
                    id: UUID(),
                    coachID: coach.id,
                    practiceID: nil,
                    authorID: p1.id,
                    authorName: p1.fullName,
                    rating: 5,
                    text: "Very clear drills and great communication.",
                    createdAt: plus(-2)
                ),
                CoachReview(
                    id: UUID(),
                    coachID: coach.id,
                    practiceID: nil,
                    authorID: p3.id,
                    authorName: p3.fullName,
                    rating: 4,
                    text: "Helpful feedback and good pace.",
                    createdAt: plus(-1)
                )
            ]
        ]

        let clubs = [
            Club(id: UUID(), name: "Downtown Arena", location: "Austin, TX", phoneNumber: "+1 (512) 555-0181", bookingHint: "Booking via phone (placeholder)."),
            Club(id: UUID(), name: "North Sports Center", location: "Dallas, TX", phoneNumber: "+1 (214) 555-0134", bookingHint: "Booking via phone (placeholder)."),
            Club(id: UUID(), name: "Riverside Courts", location: "Houston, TX", phoneNumber: "+1 (713) 555-0179", bookingHint: "Booking via phone (placeholder).")
        ]

        return InvestorDemoData(
            users: users,
            tournaments: [tournament, tournamentDraft],
            games: games.sorted { $0.startAt < $1.startAt },
            practices: practices,
            coachReviewsByCoach: reviewsByCoach,
            clubs: clubs
        )
    }

    private func syncFromBackend(currentUserID: UUID, fallbackEmail: String? = nil) async throws {
        guard let supabaseDataService else { return }
        authenticatedSupabaseUserID = currentUserID

        let fetchedUsers = (try? await supabaseDataService.fetchProfiles()) ?? []
        let fetchedClubs = (try? await supabaseDataService.fetchClubs()) ?? clubs
        let usersByID = Dictionary(
            fetchedUsers.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var fetchedGames = (try? await supabaseDataService.fetchCreatedGames(usersById: usersByID)) ?? createdGames
        var fetchedTournaments = (try? await supabaseDataService.fetchTournaments(usersById: usersByID)) ?? tournaments
        async let fetchedPracticesTask = supabaseDataService.fetchPractices()
        async let fetchedCoachReviewsTask = supabaseDataService.fetchCoachReviews()
        async let joinedPracticeIDsTask = supabaseDataService.fetchJoinedPracticeIDs(userID: currentUserID)
        let fetchedPractices = (try? await fetchedPracticesTask) ?? practices
        let fetchedCoachReviews = (try? await fetchedCoachReviewsTask) ?? []
        let fetchedJoinedPracticeIDs = (try? await joinedPracticeIDsTask) ?? []
        let reviewsByCoach = Dictionary(grouping: fetchedCoachReviews, by: \.coachID)
        var resolvedCurrentUser = fetchedUsers.first(where: { $0.id == currentUserID })
        if resolvedCurrentUser == nil, let existing = users.first(where: { $0.id == currentUserID }) {
            resolvedCurrentUser = existing
        }
        if resolvedCurrentUser == nil {
            resolvedCurrentUser = User(
                id: currentUserID,
                fullName: fallbackEmail?.components(separatedBy: "@").first ?? "Player",
                email: fallbackEmail ?? "",
                favoritePosition: "Midfielder",
                city: "",
                eloRating: 1400,
                matchesPlayed: 0,
                wins: 0,
                globalRole: .player
            )
        }

        await MainActor.run {
            users = fetchedUsers.isEmpty ? users : fetchedUsers
            clubs = fetchedClubs.isEmpty ? clubs : fetchedClubs
            createdGames = fetchedGames
            tournaments = fetchedTournaments
            practices = fetchedPractices
            joinedPracticeIDs = fetchedJoinedPracticeIDs
            coachReviewsByCoach = reviewsByCoach
            self.currentUser = resolvedCurrentUser
            if let resolvedCurrentUser,
               !users.contains(where: { $0.id == resolvedCurrentUser.id }) {
                users.append(resolvedCurrentUser)
            }
            isAuthenticated = self.currentUser != nil
        }
    }

    private func seedLocalDemoCreatedGames(for user: User?, users: [User]) {
        guard let user else {
            createdGames = []
            return
        }

        createdGames = buildDemoCreatedGames(for: user, users: users)
        refreshGameLists()
    }

    private func seedBackendDemoCreatedGames(
        for user: User,
        users: [User],
        dataService: SupabaseDataService
    ) async throws {
        let demoGames = buildDemoCreatedGames(for: user, users: users)
        for game in demoGames {
            try await dataService.createMatch(game: game)
        }
    }

    private func buildDemoCreatedGames(for user: User, users: [User]) -> [CreatedGame] {
        let otherUsers = users.filter { $0.id != user.id }
        let organiser = otherUsers.first ?? user
        let now = Date()

        let playerPool = dedupeUsersById([user] + otherUsers)
        func players(_ count: Int, including owner: User) -> [User] {
            var result = [owner]
            for candidate in playerPool where candidate.id != owner.id {
                if result.count >= count { break }
                result.append(candidate)
            }
            return result
        }

        let quickBookingGame = CreatedGame(
            id: UUID(),
            ownerId: organiser.id,
            organiserIds: [organiser.id],
            clubLocation: .downtownArena,
            startAt: Calendar.current.date(byAdding: .hour, value: 3, to: now) ?? now,
            durationMinutes: 90,
            format: .fiveVFive,
            locationName: "Downtown Arena",
            address: "Austin, TX",
            maxPlayers: 10,
            isPrivateGame: false,
            hasCourtBooked: true,
            minElo: 1000,
            maxElo: 2500,
            iAmPlaying: false,
            isRatingGame: true,
            anyoneCanInvite: true,
            anyPlayerCanInputResults: false,
            entranceWithoutConfirmation: false,
            notes: "Quick booking sample",
            createdBy: organiser.fullName,
            inviteLink: "https://sportapp.local/invite/\(UUID().uuidString)",
            players: players(5, including: organiser),
            status: .scheduled,
            isDraft: false,
            finalHomeScore: nil,
            finalAwayScore: nil,
            isDeleted: false,
            deletedAt: nil
        )

        let quickBookingGame2 = CreatedGame(
            id: UUID(),
            ownerId: organiser.id,
            organiserIds: [organiser.id],
            clubLocation: .westMiniFootballClub,
            startAt: Calendar.current.date(byAdding: .hour, value: 12, to: now) ?? now,
            durationMinutes: 75,
            format: .fiveVFive,
            locationName: "West Mini Football Club",
            address: "Austin, TX",
            maxPlayers: 10,
            isPrivateGame: false,
            hasCourtBooked: false,
            minElo: 1100,
            maxElo: 2200,
            iAmPlaying: false,
            isRatingGame: true,
            anyoneCanInvite: true,
            anyPlayerCanInputResults: false,
            entranceWithoutConfirmation: true,
            notes: "Open pick-up game",
            createdBy: organiser.fullName,
            inviteLink: "https://sportapp.local/invite/\(UUID().uuidString)",
            players: players(6, including: organiser),
            status: .scheduled,
            isDraft: false,
            finalHomeScore: nil,
            finalAwayScore: nil,
            isDeleted: false,
            deletedAt: nil
        )

        let upcomingGameOwned = CreatedGame(
            id: UUID(),
            ownerId: user.id,
            organiserIds: [user.id],
            clubLocation: .northSportsCenter,
            startAt: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now,
            durationMinutes: 90,
            format: .fiveVFive,
            locationName: "North Sports Center",
            address: "Dallas, TX",
            maxPlayers: 10,
            isPrivateGame: false,
            hasCourtBooked: true,
            minElo: 1000,
            maxElo: 2500,
            iAmPlaying: true,
            isRatingGame: true,
            anyoneCanInvite: true,
            anyPlayerCanInputResults: false,
            entranceWithoutConfirmation: false,
            notes: "Upcoming game sample",
            createdBy: user.fullName,
            inviteLink: "https://sportapp.local/invite/\(UUID().uuidString)",
            players: players(5, including: user),
            status: .scheduled,
            isDraft: false,
            finalHomeScore: nil,
            finalAwayScore: nil,
            isDeleted: false,
            deletedAt: nil
        )

        let upcomingGameOwned2 = CreatedGame(
            id: UUID(),
            ownerId: user.id,
            organiserIds: [user.id],
            clubLocation: .cityFiveLeagueHub,
            startAt: Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now,
            durationMinutes: 90,
            format: .sevenVSeven,
            locationName: "City Five League Hub",
            address: "Dallas, TX",
            maxPlayers: 14,
            isPrivateGame: false,
            hasCourtBooked: true,
            minElo: 1000,
            maxElo: 2600,
            iAmPlaying: true,
            isRatingGame: false,
            anyoneCanInvite: true,
            anyPlayerCanInputResults: false,
            entranceWithoutConfirmation: false,
            notes: "Evening community game",
            createdBy: user.fullName,
            inviteLink: "https://sportapp.local/invite/\(UUID().uuidString)",
            players: players(7, including: user),
            status: .scheduled,
            isDraft: false,
            finalHomeScore: nil,
            finalAwayScore: nil,
            isDeleted: false,
            deletedAt: nil
        )

        let pastGame = CreatedGame(
            id: UUID(),
            ownerId: user.id,
            organiserIds: [user.id],
            clubLocation: .riversideCourts,
            startAt: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now,
            durationMinutes: 90,
            format: .fiveVFive,
            locationName: "Riverside Courts",
            address: "Houston, TX",
            maxPlayers: 10,
            isPrivateGame: false,
            hasCourtBooked: true,
            minElo: 1000,
            maxElo: 2500,
            iAmPlaying: true,
            isRatingGame: true,
            anyoneCanInvite: false,
            anyPlayerCanInputResults: false,
            entranceWithoutConfirmation: false,
            notes: "Past game sample",
            createdBy: user.fullName,
            inviteLink: nil,
            players: players(5, including: user),
            status: .completed,
            isDraft: false,
            finalHomeScore: 3,
            finalAwayScore: 2,
            isDeleted: false,
            deletedAt: nil
        )

        return [quickBookingGame, quickBookingGame2, upcomingGameOwned, upcomingGameOwned2, pastGame]
            .sorted { $0.startAt < $1.startAt }
    }
}
