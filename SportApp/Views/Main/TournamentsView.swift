import SwiftUI

struct TournamentsView: View {
    private enum PlayFilter {
        case games
        case tournaments
        case practices
    }
    
    private enum PlayRoute: Hashable {
        case game(UUID)
    }

    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var selectedFilter: PlayFilter = .games
    @State private var navigationPath: [PlayRoute] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    filterButton(
                        title: "Games",
                        isSelected: selectedFilter == .games
                    ) {
                        selectedFilter = .games
                    }

                    filterButton(
                        title: "Tournaments",
                        isSelected: selectedFilter == .tournaments
                    ) {
                        selectedFilter = .tournaments
                    }

                    filterButton(
                        title: "Practices",
                        isSelected: selectedFilter == .practices
                    ) {
                        selectedFilter = .practices
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)

                if selectedFilter == .games {
                    List {
                        if appViewModel.discoverableUpcomingCreatedGames.isEmpty {
                            Text("No upcoming games from other players.")
                                .foregroundStyle(.secondary)
                        } else {
                            Section {
                                ForEach(appViewModel.discoverableUpcomingCreatedGames) { game in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(game.locationName)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text(game.isPrivateGame ? "Private" : "Public")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(DateFormatterService.tournamentDateTime.string(from: game.scheduledDate))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("Players: \(game.players.count)/\(game.numberOfPlayers) • Avg Elo: \(game.averageElo)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        HStack(spacing: 8) {
                                            NavigationLink(value: PlayRoute.game(game.id)) {
                                                Text("Open")
                                            }
                                            .buttonStyle(.bordered)

                                            if appViewModel.currentUser != nil,
                                               game.status == .scheduled,
                                               game.scheduledDate >= Date() {
                                                let joined = appViewModel.isCurrentUserGoingInGame(game.id)
                                                Button(joined ? "Leave Game" : "Join Game") {
                                                    if joined {
                                                        appViewModel.leaveCreatedGame(gameID: game.id)
                                                    } else {
                                                        if appViewModel.joinCreatedGame(gameID: game.id) {
                                                            navigationPath = [.game(game.id)]
                                                        }
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                            }
                                        }
                                    }
                                }
                            } header: {
                                Text("Upcoming Games")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .appListBackground()
                } else if selectedFilter == .tournaments {
                    List {
                        let upcomingTournaments = appViewModel.visibleTournaments
                            .filter { appViewModel.canCurrentUserSeeTournament($0) }
                            .filter { $0.startDate >= Date() && !$0.isDeleted }
                            .sorted { $0.startDate < $1.startDate }

                        if upcomingTournaments.isEmpty {
                            Text("No upcoming tournaments.")
                                .foregroundStyle(.secondary)
                        } else {
                            Section {
                                ForEach(upcomingTournaments) { tournament in
                                    NavigationLink {
                                        TournamentDetailView(tournamentID: tournament.id)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(tournament.title)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text(DateFormatterService.tournamentDateTime.string(from: tournament.startDate))
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            Text("Open team slots: \(tournament.openSpots)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } header: {
                                Text("Upcoming Tournaments")
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .appListBackground()
                } else {
                    List {
                        let upcomingPractices = appViewModel.visiblePractices
                            .filter { $0.startDate >= Date() }
                            .sorted { $0.startDate < $1.startDate }

                        if upcomingPractices.isEmpty {
                            Text("No upcoming practices.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(upcomingPractices) { practice in
                                VStack(alignment: .leading, spacing: 6) {
                                    if let coachId = practice.ownerId,
                                       let coach = appViewModel.user(with: coachId) {
                                        HStack(spacing: 8) {
                                            PlayerAvatarView(
                                                name: coach.fullName,
                                                imageData: coach.avatarImageData,
                                                size: 26
                                            )
                                            Text(coach.fullName)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    HStack {
                                        Text(practice.title)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text(practice.isOpenJoin ? "Open" : "Private")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(DateFormatterService.tournamentDateTime.string(from: practice.startDate))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("\(practice.location) • Players: \(practice.numberOfPlayers)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Elo: \(practice.minElo)-\(practice.maxElo)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    if let currentUser = appViewModel.currentUser {
                                        let joined = appViewModel.isCurrentUserJoinedPractice(practice.id)
                                        let isPracticeOpenForJoinLeave = practice.startDate.addingTimeInterval(TimeInterval(max(practice.durationMinutes, 0) * 60)) > Date()
                                        HStack(spacing: 8) {
                                            NavigationLink {
                                                PracticeDetailView(practiceID: practice.id)
                                            } label: {
                                                Text("Open")
                                            }
                                            .buttonStyle(.bordered)

                                            if isPracticeOpenForJoinLeave &&
                                                (practice.isOpenJoin || practice.ownerId == currentUser.id || practice.organiserIds.contains(currentUser.id) || currentUser.isAdmin) {
                                                Button(joined ? "Leave Practice" : "Join Practice") {
                                                    if joined {
                                                        appViewModel.leavePractice(sessionID: practice.id)
                                                    } else {
                                                        appViewModel.joinPractice(sessionID: practice.id)
                                                    }
                                                }
                                                .buttonStyle(.bordered)
                                            } else {
                                                Text("Private practice (invite link)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .appListBackground()
                }
            }
            .appScreenBackground()
            .navigationTitle("Play")
            .navigationDestination(for: PlayRoute.self) { route in
                switch route {
                case .game(let gameID):
                    if let game = appViewModel.createdGame(for: gameID) {
                    GameDetailView(game: game)
                    } else {
                        Text("Game not found")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .white : .primary)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
        )
    }
}

struct GameDetailView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let game: CreatedGame

    private var displayedGame: CreatedGame {
        appViewModel.createdGame(for: game.id) ?? game
    }

    private var openSlots: Int {
        max(displayedGame.numberOfPlayers - displayedGame.players.count, 0)
    }

    private var addressText: String {
        if displayedGame.address.isEmpty {
            return displayedGame.locationName
        }
        return "\(displayedGame.locationName), \(displayedGame.address)"
    }

    private var isJoinedByCurrentUser: Bool {
        appViewModel.isCurrentUserGoingInGame(displayedGame.id)
    }

    private var isGameOpenForJoinLeave: Bool {
        displayedGame.status == .scheduled
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(DateFormatterService.tournamentDateTime.string(from: displayedGame.scheduledDate), systemImage: "clock.fill")
                    Label(addressText, systemImage: "mappin.and.ellipse")
                    Label("Duration: \(displayedGame.durationMinutes) min • \(displayedGame.format.rawValue)", systemImage: "timer")
                    Label(displayedGame.hasCourtBooked ? "Field booked" : "Field not booked", systemImage: "sportscourt.fill")
                    Label(displayedGame.isRatingGame ? "Rating game" : "Not rating game", systemImage: "chart.bar.fill")
                    Label("Average Elo: \(displayedGame.averageElo)", systemImage: "gauge.with.dots.needle.67percent")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.95), Color.indigo.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Players: \(displayedGame.players.count)/\(displayedGame.numberOfPlayers)")
                        .font(.title3.bold())

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                        ForEach(displayedGame.players) { player in
                            PlayerSlotView(name: player.fullName, avatarImageData: player.avatarImageData, elo: player.eloRating)
                        }

                        ForEach(0..<openSlots, id: \.self) { _ in
                            EmptySlotView()
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                if appViewModel.currentUser != nil && isGameOpenForJoinLeave {
                    Button(isJoinedByCurrentUser ? "Leave Game" : "Join Game") {
                        if isJoinedByCurrentUser {
                            appViewModel.leaveCreatedGame(gameID: displayedGame.id)
                        } else {
                            appViewModel.joinCreatedGame(gameID: displayedGame.id)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                NavigationLink {
                    MatchDetailsView(match: makeMatch())
                } label: {
                    HStack {
                        Text("Open Match Details")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .appScreenBackground()
        .navigationTitle("Game")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func makeMatch() -> Match {
        let allPlayers = displayedGame.players
        let splitIndex = max(allPlayers.count / 2, 1)
        let homePlayers = Array(allPlayers.prefix(splitIndex))
        let awayPlayers = Array(allPlayers.dropFirst(splitIndex))

        let homeTeam = Team(
            id: UUID(),
            name: "Home Team",
            members: homePlayers,
            maxPlayers: max(displayedGame.numberOfPlayers / 2, 1)
        )

        let awayTeam = Team(
            id: UUID(),
            name: "Away Team",
            members: awayPlayers,
            maxPlayers: max(displayedGame.numberOfPlayers / 2, 1)
        )

        let participants = homePlayers.map {
            Participant(
                id: $0.id,
                name: $0.fullName,
                teamId: homeTeam.id,
                elo: $0.eloRating,
                positionGroup: positionGroup(for: $0)
            )
        } + awayPlayers.map {
            Participant(
                id: $0.id,
                name: $0.fullName,
                teamId: awayTeam.id,
                elo: $0.eloRating,
                positionGroup: positionGroup(for: $0)
            )
        }

        let seedEvents: [MatchEvent]
        let ownerId = displayedGame.ownerId
        if let first = participants.first {
            seedEvents = [
                MatchEvent(
                    id: UUID(),
                    type: .goal,
                    minute: 8,
                    playerId: first.id,
                    createdById: first.id,
                    createdAt: Date()
                )
            ]
        } else {
            seedEvents = []
        }

        return Match(
            id: displayedGame.id,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            participants: participants,
            events: seedEvents,
            location: addressText,
            startTime: displayedGame.scheduledDate,
            format: displayedGame.format.rawValue,
            notes: displayedGame.notes,
            isRatingGame: displayedGame.isRatingGame,
            isFieldBooked: displayedGame.hasCourtBooked,
            isPrivateGame: displayedGame.isPrivateGame,
            maxPlayers: displayedGame.numberOfPlayers,
            ownerId: ownerId,
            organiserIds: [ownerId]
        )
    }

    private func positionGroup(for user: User) -> PositionGroup {
        guard let raw = user.preferredPositions.first?.rawValue.uppercased() else { return .bench }
        switch raw {
        case "GK":
            return .gk
        case "CB", "LB", "RB", "LWB", "RWB":
            return .defenders
        case "DM", "CM", "AM", "LM", "RM":
            return .midfielders
        case "LW", "RW", "ST", "CF", "SS":
            return .forwards
        default:
            return .bench
        }
    }
}

private struct PlayerSlotView: View {
    let name: String
    let avatarImageData: Data?
    let elo: Int

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                PlayerAvatarView(name: name, imageData: avatarImageData, size: 58)

                Text("\(elo)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.9), in: Capsule())
                    .foregroundStyle(.white)
                    .offset(x: 8, y: -6)
            }

            Text(name.components(separatedBy: " ").first ?? name)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

private struct EmptySlotView: View {
    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                .foregroundStyle(.secondary)
                .frame(width: 58, height: 58)
                .overlay(
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                )

            Text("Invite")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct PracticeDetailView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let practiceID: UUID
    @State private var reviewRating: Int = 5
    @State private var reviewText: String = ""
    @State private var showPracticeEditSheet = false
    @State private var showEndPracticeConfirmation = false
    @State private var showDeletePracticeConfirmation = false

    private var practice: PracticeSession? {
        appViewModel.visiblePractices.first(where: { $0.id == practiceID })
    }

    private var coach: User? {
        guard let ownerId = practice?.ownerId else { return nil }
        return appViewModel.user(with: ownerId)
    }

    private var isJoined: Bool {
        appViewModel.isCurrentUserJoinedPractice(practiceID)
    }

    private var canJoinDirectly: Bool {
        guard let practice, let currentUser = appViewModel.currentUser else { return false }
        guard isPracticeOpenForJoinLeave else { return false }
        return practice.isOpenJoin
            || practice.ownerId == currentUser.id
            || practice.organiserIds.contains(currentUser.id)
            || currentUser.isAdmin
    }

    private var isPracticeOpenForJoinLeave: Bool {
        guard let practice else { return false }
        let end = practice.startDate.addingTimeInterval(TimeInterval(max(practice.durationMinutes, 0) * 60))
        return end > Date()
    }

    private var joinedPlayers: [User] {
        guard let currentUser = appViewModel.currentUser, isJoined else { return [] }
        return [currentUser]
    }

    private var canLeaveCoachReview: Bool {
        guard let practice else { return false }
        return appViewModel.canCurrentUserReviewPractice(practice)
    }

    private var hasCurrentUserReviewForPractice: Bool {
        appViewModel.hasCurrentUserReviewedPractice(practiceID)
    }

    private var canManagePractice: Bool {
        guard let practice else { return false }
        return appViewModel.canCurrentUserEditPractice(practice)
    }

    var body: some View {
        Group {
            if let practice {
                ScrollView {
                    VStack(spacing: 14) {
                        headerCard(practice)
                        organiserToolsCard(practice)
                        playersCard(practice)
                        coachReviewCard(practice)
                    }
                    .padding()
                }
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.01, green: 0.14, blue: 0.27), Color(red: 0.02, green: 0.20, blue: 0.38)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
                .safeAreaInset(edge: .bottom) {
                    if appViewModel.currentUser != nil {
                        bottomCTA(practice)
                    }
                }
            } else {
                Text("Practice not found")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Practice Action", isPresented: practiceActionAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appViewModel.tournamentActionMessage ?? "")
        }
        .alert("End practice?", isPresented: $showEndPracticeConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("End Practice", role: .destructive) {
                appViewModel.endPractice(practiceID)
            }
        } message: {
            Text("This will move the practice to past sessions and unlock post-practice reviews.")
        }
        .alert("Delete practice?", isPresented: $showDeletePracticeConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                appViewModel.deletePractice(practiceID)
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showPracticeEditSheet) {
            if let practice {
                PracticeEditSheet(
                    session: practice,
                    onSave: { updated in
                        appViewModel.updatePractice(updated)
                        showPracticeEditSheet = false
                    },
                    onCancel: {
                        showPracticeEditSheet = false
                    }
                )
            }
        }
    }

    private func headerCard(_ practice: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(practice.title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.78, green: 0.93, blue: 0.35))

            if let coach {
                NavigationLink {
                    PublicProfileView(userID: coach.id)
                } label: {
                    HStack(spacing: 8) {
                        Text("Organiser")
                            .foregroundStyle(Color(red: 0.78, green: 0.93, blue: 0.35))
                        Text(coach.fullName)
                            .foregroundStyle(.white)
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color(red: 0.23, green: 0.66, blue: 1.0))
                    }
                    .font(.title3.weight(.semibold))
                }
                .buttonStyle(.plain)
            }

            Label(timeRangeText(start: practice.startDate, durationMinutes: practice.durationMinutes), systemImage: "clock.fill")
            Label(practice.location, systemImage: "mappin.and.ellipse")
            Label("Focus: \(practice.focusArea)", systemImage: "target")
            Label(practice.isOpenJoin ? "Open entry" : "Private (invite link)", systemImage: "message.fill")

            if !practice.notes.isEmpty {
                Text(practice.notes)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.top, 2)
            }

            if let coach {
                NavigationLink {
                    PublicProfileView(userID: coach.id)
                } label: {
                    HStack(spacing: 8) {
                        PlayerAvatarView(name: coach.fullName, imageData: coach.avatarImageData, size: 28)
                        Text(coach.fullName + " (coach)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(10)
                    .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .font(.title3.weight(.medium))
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.36, blue: 0.64), Color(red: 0.14, green: 0.42, blue: 0.73)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private func playersCard(_ practice: PracticeSession) -> some View {
        let filled = joinedPlayers.count
        let total = max(practice.numberOfPlayers, 1)
        let open = max(total - filled, 0)
        let freeSlotsToRender = min(open, 5)

        return VStack(alignment: .leading, spacing: 14) {
            Text("Players: \(filled)/\(total)")
                .font(.title2.bold())
                .foregroundStyle(.white)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                ForEach(joinedPlayers) { user in
                    VStack(spacing: 6) {
                        PlayerAvatarView(name: user.fullName, imageData: user.avatarImageData, size: 54)
                        Text(user.fullName.components(separatedBy: " ").first ?? user.fullName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }

                ForEach(0..<freeSlotsToRender, id: \.self) { _ in
                    VStack(spacing: 6) {
                        Circle()
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .fill(Color.white.opacity(0.75))
                            .frame(width: 54, height: 54)
                            .overlay(
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Color(red: 0.76, green: 0.9, blue: 0.26))
                            )
                        Text("Free")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func organiserToolsCard(_ practice: PracticeSession) -> some View {
        if canManagePractice {
            VStack(alignment: .leading, spacing: 10) {
                Text("Organiser Tools")
                    .font(.headline)
                    .foregroundStyle(.white)

                Button("Edit Practice Details") {
                    showPracticeEditSheet = true
                }
                .buttonStyle(.borderedProminent)

                Button("End Practice") {
                    showEndPracticeConfirmation = true
                }
                .buttonStyle(.bordered)
                .disabled(!isPracticeOpenForJoinLeave)

                Button("Delete Practice", role: .destructive) {
                    showDeletePracticeConfirmation = true
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func bottomCTA(_ practice: PracticeSession) -> some View {
        Group {
            if canJoinDirectly {
                Button(isJoined ? "Leave Practice" : "Join Practice") {
                    if isJoined {
                        appViewModel.leavePractice(sessionID: practice.id)
                    } else {
                        appViewModel.joinPractice(sessionID: practice.id)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .font(.title3.bold())
                .foregroundStyle(Color(red: 0.01, green: 0.12, blue: 0.24))
                .background(Color(red: 0.78, green: 0.93, blue: 0.35), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(Color.black.opacity(0.22))
            } else {
                Text(isPracticeOpenForJoinLeave ? "Private practice. Join via invite link." : "Practice finished. Join/leave is locked.")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
        }
    }

    @ViewBuilder
    private func coachReviewCard(_ practice: PracticeSession) -> some View {
        if !isPracticeOpenForJoinLeave {
            VStack(alignment: .leading, spacing: 10) {
                Text("Coach Review")
                    .font(.headline)
                    .foregroundStyle(.white)

                if canLeaveCoachReview, let coachID = practice.ownerId {
                    Picker("Rating", selection: $reviewRating) {
                        ForEach(1...5, id: \.self) { value in
                            Text("\(value) ★").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextEditor(text: $reviewText)
                        .frame(minHeight: 90)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 10))

                    Button("Submit Review") {
                        appViewModel.addReview(
                            to: coachID,
                            practiceID: practice.id,
                            rating: reviewRating,
                            text: reviewText
                        )
                        reviewText = ""
                        reviewRating = 5
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else if hasCurrentUserReviewForPractice {
                    Text("You already left a review for this practice.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Review becomes available only to attending players after practice is finished.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var practiceActionAlertBinding: Binding<Bool> {
        Binding(
            get: { appViewModel.tournamentActionMessage != nil },
            set: { isPresented in
                if !isPresented {
                    appViewModel.tournamentActionMessage = nil
                }
            }
        )
    }

    private func timeRangeText(start: Date, durationMinutes: Int) -> String {
        let end = start.addingTimeInterval(TimeInterval(max(durationMinutes, 0) * 60))
        return "\(DateFormatterService.tournamentDateTime.string(from: start)) - \(Self.hourMinuteFormatter.string(from: end))"
    }

    private static let hourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private struct PracticeEditSheet: View {
    @State private var title: String
    @State private var location: String
    @State private var startDate: Date
    @State private var durationMinutes: Int
    @State private var numberOfPlayers: Int
    @State private var minElo: Int
    @State private var maxElo: Int
    @State private var isOpenJoin: Bool
    @State private var focusArea: String
    @State private var notes: String

    let session: PracticeSession
    let onSave: (PracticeSession) -> Void
    let onCancel: () -> Void

    init(session: PracticeSession, onSave: @escaping (PracticeSession) -> Void, onCancel: @escaping () -> Void) {
        self.session = session
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: session.title)
        _location = State(initialValue: session.location)
        _startDate = State(initialValue: session.startDate)
        _durationMinutes = State(initialValue: session.durationMinutes)
        _numberOfPlayers = State(initialValue: session.numberOfPlayers)
        _minElo = State(initialValue: session.minElo)
        _maxElo = State(initialValue: session.maxElo)
        _isOpenJoin = State(initialValue: session.isOpenJoin)
        _focusArea = State(initialValue: session.focusArea)
        _notes = State(initialValue: session.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextField("Location", text: $location)
                    DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 30...240, step: 15)
                    Stepper("Players: \(numberOfPlayers)", value: $numberOfPlayers, in: 2...60)
                }

                Section("Session") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Elo Range: \(minElo)-\(maxElo)")
                            .font(.subheadline)
                        Slider(
                            value: Binding(
                                get: { Double(minElo) },
                                set: { minElo = min(Int($0), maxElo) }
                            ),
                            in: 800...3000,
                            step: 25
                        )
                        Slider(
                            value: Binding(
                                get: { Double(maxElo) },
                                set: { maxElo = max(Int($0), minElo) }
                            ),
                            in: 800...3000,
                            step: 25
                        )
                    }
                    Toggle("Open Join", isOn: $isOpenJoin)
                    TextField("Focus Area", text: $focusArea)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = session
                        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.startDate = startDate
                        updated.durationMinutes = durationMinutes
                        updated.numberOfPlayers = numberOfPlayers
                        updated.minElo = min(minElo, maxElo)
                        updated.maxElo = max(minElo, maxElo)
                        updated.isOpenJoin = isOpenJoin
                        updated.focusArea = focusArea.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(updated)
                    }
                }
            }
        }
    }
}
