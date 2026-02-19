import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Group {
                if let user = appViewModel.currentUser {
                    PlayerProfileEditorView(user: user) {
                        appViewModel.signOut()
                    }
                    .id(user.id)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No profile loaded")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

private struct PlayerProfileEditorView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: PlayerProfileViewModel
    private let user: User
    private let eloRating: Int
    private let onSignOut: () -> Void
#if DEBUG
    @State private var isDebugSwitcherPresented = false
#endif
    @State private var selectedPhotoItem: PhotosPickerItem?

    init(user: User, repository: (any PlayerProfileRepository)? = nil, onSignOut: @escaping () -> Void) {
        let seedPlayer = Player.from(user: user)
        let repo = repository ?? MockPlayerProfileRepository(seedPlayer: seedPlayer)
        _viewModel = StateObject(wrappedValue: PlayerProfileViewModel(playerID: user.id, repository: repo))
        self.user = user
        self.eloRating = user.eloRating
        self.onSignOut = onSignOut
    }

    var body: some View {
        List {
            Section("Player Profile") {
                VStack(alignment: .leading, spacing: 10) {
                    PlayerAvatarView(
                        name: viewModel.name.isEmpty ? user.fullName : viewModel.name,
                        imageData: viewModel.avatarImageData,
                        size: 56
                    )

                    TextField("Name", text: $viewModel.name)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Upload Image", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.bordered)
                }

                Picker("Main Position", selection: $viewModel.mainPosition) {
                    ForEach(MainPosition.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }

                TextField("Location", text: $viewModel.location)

                NavigationLink {
                    PositionPickerView(selectedPositions: $viewModel.preferredPositions) { _ in }
                } label: {
                    HStack {
                        Text("Preferred Position")
                        Spacer()
                        Text(preferredPositionsSummary)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if !viewModel.preferredPositions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(viewModel.preferredPositions) { position in
                                Text(position.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .foregroundStyle(.white)
                                    .background(Color.blue, in: Capsule())
                            }
                        }
                    }
                }

                Picker("Preferred foot", selection: $viewModel.preferredFoot) {
                    ForEach(PreferredFoot.allCases) { foot in
                        Text(foot.rawValue).tag(foot)
                    }
                }
            }

            Section {
                Button {
                    Task {
                        await persistProfileChanges()
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Save Profile")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            Section("Mini Stats") {
                statRow(title: "Matches Played", value: "\(viewModel.completedMatchesPlayed)")
                statRow(title: "Wins", value: "\(viewModel.winsCount)")
                statRow(title: "Draws", value: "\(viewModel.drawsCount)")
                statRow(title: "Losses", value: "\(viewModel.lossesCount)")
            }

            Section("Upcoming") {
                if appViewModel.currentUserUpcomingCreatedGames.isEmpty && appViewModel.currentUserUpcomingTournaments.isEmpty {
                    Text("No upcoming matches or tournaments")
                        .foregroundStyle(.secondary)
                } else {
                    createdGameSubsection(title: "Matches", games: appViewModel.currentUserUpcomingCreatedGames)
                    tournamentSubsection(title: "Tournaments", tournaments: appViewModel.currentUserUpcomingTournaments)
                }
            }

            Section("Past") {
                if appViewModel.currentUserPastCreatedGames.isEmpty && appViewModel.currentUserPastTournaments.isEmpty {
                    Text("No past matches or tournaments")
                        .foregroundStyle(.secondary)
                } else {
                    createdGameSubsection(title: "Matches", games: appViewModel.currentUserPastCreatedGames)
                    tournamentSubsection(title: "Tournaments", tournaments: appViewModel.currentUserPastTournaments)
                }
            }

            if user.isCoachActive {
                Section("Coach Access") {
                    practiceSubsection(title: "Upcoming Practices", sessions: coachUpcomingPractices)
                    practiceSubsection(title: "Past Practices", sessions: coachPastPractices)
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    onSignOut()
                }
            }

#if DEBUG
            Section {
                Text(debugVersionLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 3) {
                        isDebugSwitcherPresented = true
                    }
            }
#endif
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
#if DEBUG
        .sheet(isPresented: $isDebugSwitcherPresented) {
            DebugSwitchUserView()
                .environmentObject(appViewModel)
        }
#endif
        .task {
            await viewModel.loadProfile()
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.avatarImageData = data
                }
                selectedPhotoItem = nil
            }
        }
    }

#if DEBUG
    private var debugVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "v\(version) (\(build))"
    }
#endif

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private var preferredPositionsSummary: String {
        let selected = viewModel.preferredPositions.map(\.rawValue)
        return selected.isEmpty ? "None" : selected.joined(separator: " • ")
    }

    private func createdGameSubsection(title: String, games: [CreatedGame]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.top, 2)

            if games.isEmpty {
                Text("No \(title.lowercased()) game matches")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(games.prefix(5)) { game in
                    NavigationLink {
                        GameDetailView(game: game)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(game.locationName)
                                    .font(.headline)
                                Spacer()
                                Text("Avg Elo \(game.averageElo)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(DateFormatterService.tournamentDateTime.string(from: game.startAt))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Players: \(game.players.count)/\(game.maxPlayers)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func tournamentSubsection(title: String, tournaments: [Tournament]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.top, 2)

            if tournaments.isEmpty {
                Text("No \(title.lowercased()) tournaments")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tournaments.prefix(5)) { tournament in
                    NavigationLink {
                        TournamentDetailView(tournamentID: tournament.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(tournament.title)
                                    .font(.headline)
                                Spacer()
                                Text(tournament.location)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(DateFormatterService.tournamentDateTime.string(from: tournament.startDate))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Teams: \(tournament.teams.count)/\(tournament.maxTeams)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var coachUpcomingPractices: [PracticeSession] {
        appViewModel.visiblePractices
            .filter { session in
                session.ownerId == user.id || session.organiserIds.contains(user.id)
            }
            .filter { $0.startDate >= Date() }
            .sorted { $0.startDate < $1.startDate }
    }

    private var coachPastPractices: [PracticeSession] {
        appViewModel.visiblePractices
            .filter { session in
                session.ownerId == user.id || session.organiserIds.contains(user.id)
            }
            .filter { $0.startDate < Date() }
            .sorted { $0.startDate > $1.startDate }
    }

    private func practiceSubsection(title: String, sessions: [PracticeSession]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.top, 2)

            if sessions.isEmpty {
                Text("No practices")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions.prefix(5)) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.title)
                                .font(.headline)
                            Spacer()
                            Text(session.location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(DateFormatterService.tournamentDateTime.string(from: session.startDate))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Players: \(session.numberOfPlayers) • Elo: \(session.minElo)-\(session.maxElo)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func persistProfileChanges() async {
        guard let savedPlayer = await viewModel.saveProfile() else {
            return
        }
        appViewModel.applyProfileUpdate(from: savedPlayer)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            profilePreview
            profileEditorPreview
        }
    }

    private static var profilePreview: some View {
        let appViewModel = AppViewModel()
        appViewModel.currentUser = MockDataService.seedUsers().first

        return ProfileView()
            .environmentObject(appViewModel)
            .previewDisplayName("Profile")
    }

    private static var profileEditorPreview: some View {
        let user = MockDataService.seedUsers().first ?? User(
            id: UUID(),
            fullName: "Preview Player",
            email: "preview@sportapp.test",
            favoritePosition: "Winger",
            city: "Austin",
            eloRating: 1500,
            matchesPlayed: 0,
            wins: 0
        )

        return NavigationStack {
            PlayerProfileEditorView(
                user: user,
                repository: MockPlayerProfileRepository(seedPlayer: Player.from(user: user))
            ) {}
            .navigationTitle("Profile")
        }
        .previewDisplayName("Profile Editor")
    }
}

struct PublicProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let userID: UUID

    private var user: User? {
        appViewModel.user(with: userID)
    }

    var body: some View {
        Group {
            if let user {
                if user.isCoachActive {
                    CoachPublicProfileView(user: user)
                } else {
                    PlayerPublicProfileView(user: user)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Profile not found")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct PlayerPublicProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let user: User

    private var upcomingGames: [CreatedGame] { appViewModel.upcomingCreatedGames(for: user.id) }
    private var pastGames: [CreatedGame] { appViewModel.pastCreatedGames(for: user.id) }
    private var upcomingTournaments: [Tournament] { appViewModel.upcomingTournaments(for: user.id) }
    private var pastTournaments: [Tournament] { appViewModel.pastTournaments(for: user.id) }

    var body: some View {
        List {
            Section {
                publicHeroCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            gamesSection(title: "Upcoming Games", games: upcomingGames)
            tournamentsSection(title: "Upcoming Tournaments", tournaments: upcomingTournaments)
            gamesSection(title: "Past Games", games: pastGames)
            tournamentsSection(title: "Past Tournaments", tournaments: pastTournaments)
        }
        .navigationTitle(user.fullName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var publicHeroCard: some View {
        let totalGames = upcomingGames.count + pastGames.count
        let totalTournaments = upcomingTournaments.count + pastTournaments.count
        let totalPartners = appViewModel.partnersCount(for: user.id)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PlayerAvatarView(name: user.fullName, imageData: user.avatarImageData, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(user.city)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    RoleBadge(tags: RoleTagProvider.tags(for: user), size: .small)
                }
            }

            HStack(spacing: 12) {
                heroStat(label: "Tournaments", value: totalTournaments)
                heroStat(label: "Games", value: totalGames)
                heroStat(label: "Partners", value: totalPartners)
            }

            Divider()
                .overlay(.white.opacity(0.2))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ELO")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("\(user.eloRating)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("W/D/L: \(user.wins)/\(user.draws)/\(user.losses)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }

            if !user.preferredPositions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(user.preferredPositions) { position in
                            Text(position.rawValue)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundStyle(.white)
                                .background(Color.white.opacity(0.2), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.95), Color.indigo.opacity(0.85), Color.black.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .padding(.horizontal, 16)
    }

    private func heroStat(label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(Color.green.opacity(0.95))
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }

    private func gamesSection(title: String, games: [CreatedGame]) -> some View {
        Section(title) {
            if games.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(games.prefix(8)) { game in
                    NavigationLink {
                        GameDetailView(game: game)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(game.locationName)
                                .font(.headline)
                            Text(DateFormatterService.tournamentDateTime.string(from: game.startAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func tournamentsSection(title: String, tournaments: [Tournament]) -> some View {
        Section(title) {
            if tournaments.isEmpty {
                Text("No tournaments")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tournaments.prefix(8)) { tournament in
                    NavigationLink {
                        TournamentDetailView(tournamentID: tournament.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tournament.title)
                                .font(.headline)
                            Text(DateFormatterService.tournamentDateTime.string(from: tournament.startDate))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CoachPublicProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let user: User

    @State private var reviewRating: Int = 5
    @State private var reviewText: String = ""

    private var reviews: [CoachReview] {
        appViewModel.reviews(for: user.id)
    }

    private var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        return Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)
    }

    private var canAddReview: Bool {
        guard let current = appViewModel.currentUser else { return false }
        return current.id != user.id
    }

    var body: some View {
        List {
            Section {
                coachHeroCard
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if canAddReview {
                Section("Leave Review") {
                    Picker("Rating", selection: $reviewRating) {
                        ForEach(1...5, id: \.self) { value in
                            Text("\(value) ★").tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextEditor(text: $reviewText)
                        .frame(minHeight: 90)

                    Button("Submit Review") {
                        appViewModel.addReview(to: user.id, rating: reviewRating, text: reviewText)
                        reviewText = ""
                        reviewRating = 5
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section("Reviews") {
                if reviews.isEmpty {
                    Text("No reviews yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reviews) { review in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(review.authorName)
                                    .font(.headline)
                                Spacer()
                                Text(String(repeating: "★", count: review.rating))
                                    .foregroundStyle(.yellow)
                            }
                            Text(review.text)
                                .font(.subheadline)
                            Text(DateFormatterService.tournamentDateTime.string(from: review.createdAt))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Practices") {
                practiceSection(title: "Upcoming Practices", sessions: upcomingPractices)
                practiceSection(title: "Past Practices", sessions: pastPractices)
            }
        }
        .navigationTitle(user.fullName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var coachHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PlayerAvatarView(name: user.fullName, imageData: user.avatarImageData, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(user.city)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                    RoleBadge(tags: RoleTagProvider.tags(for: user), size: .small)
                }
            }

            HStack(spacing: 12) {
                coachHeroStat(label: "Reviews", value: reviews.count)
                coachHeroStat(label: "ELO", value: user.eloRating)
                coachHeroStat(label: "Rating", value: Int(round(averageRating * 10)))
            }

            Divider()
                .overlay(.white.opacity(0.2))

            Text(reviews.isEmpty ? "No ratings yet" : String(format: "Average rating: %.1f / 5", averageRating))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.95), Color.indigo.opacity(0.85), Color.black.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .padding(.horizontal, 16)
    }

    private func coachHeroStat(label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(Color.green.opacity(0.95))
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
    }

    private var upcomingPractices: [PracticeSession] {
        appViewModel.visiblePractices
            .filter { session in
                session.ownerId == user.id || session.organiserIds.contains(user.id)
            }
            .filter { $0.startDate >= Date() }
            .sorted { $0.startDate < $1.startDate }
    }

    private var pastPractices: [PracticeSession] {
        appViewModel.visiblePractices
            .filter { session in
                session.ownerId == user.id || session.organiserIds.contains(user.id)
            }
            .filter { $0.startDate < Date() }
            .sorted { $0.startDate > $1.startDate }
    }

    private func practiceSection(title: String, sessions: [PracticeSession]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            if sessions.isEmpty {
                Text("No practices")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions.prefix(8)) { practice in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(practice.title)
                                .font(.headline)
                            Spacer()
                            Text(practice.location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(DateFormatterService.tournamentDateTime.string(from: practice.startDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Players: \(practice.numberOfPlayers) • Elo: \(practice.minElo)-\(practice.maxElo)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
