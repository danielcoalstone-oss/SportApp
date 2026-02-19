import SwiftUI

enum AppTheme {
    static let backgroundTop = Color(red: 0.01, green: 0.14, blue: 0.27)
    static let backgroundBottom = Color(red: 0.02, green: 0.20, blue: 0.38)
    static let cardTop = Color(red: 0.11, green: 0.36, blue: 0.64)
    static let cardBottom = Color(red: 0.14, green: 0.42, blue: 0.73)
    static let accent = Color(red: 0.78, green: 0.93, blue: 0.35)
    static let overlayCard = Color.black.opacity(0.48)
}

struct AppBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

extension View {
    func appScreenBackground() -> some View {
        background(AppBackgroundView())
    }

    func appListBackground() -> some View {
        scrollContentBackground(.hidden)
            .listRowBackground(Color.black.opacity(0.55))
            .listRowSeparatorTint(.white.opacity(0.14))
            .background(AppBackgroundView())
    }

    func appCard() -> some View {
        background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppTheme.overlayCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    func appPrimaryAction() -> some View {
        foregroundStyle(AppTheme.backgroundTop)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            TournamentsView()
                .tabItem {
                    Label("Play", systemImage: "sportscourt")
                }

            LeaderboardView()
                .tabItem {
                    Label("Ratings", systemImage: "list.number")
                }

            CreateHubView()
                .tabItem {
                    Label("Create", systemImage: "plus.circle")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }

            if appViewModel.currentUser?.isAdmin == true {
                AdminView()
                    .tabItem {
                        Label("Admin", systemImage: "lock.shield")
                    }
            }
        }
        .tint(AppTheme.accent)
    }
}

struct CreateHubView: View {
    private enum CreatedDestination: Hashable {
        case game(UUID)
        case tournament(UUID)
        case practice(UUID)
    }

    private enum CreateTab: String, CaseIterable, Identifiable {
        case game = "Game"
        case tournament = "Tournament"
        case practice = "Practice"
        case drafts = "Drafts"

        var id: String { rawValue }
    }

    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var selectedTab: CreateTab = .game
    @State private var createNavigationPath: [CreatedDestination] = []

    private var availableTabs: [CreateTab] {
        var tabs: [CreateTab] = [.game]
        if appViewModel.canCurrentUserCreateTournamentFromCreateTab {
            tabs.append(.tournament)
        }
        if appViewModel.canCurrentUserCreatePracticeFromCreateTab {
            tabs.append(.practice)
        }
        tabs.append(.drafts)
        return tabs
    }

    var body: some View {
        NavigationStack(path: $createNavigationPath) {
            VStack(spacing: 12) {
                Picker("Create", selection: $selectedTab) {
                    ForEach(availableTabs) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch selectedTab {
                    case .game:
                        CreateGameView { gameID in
                            createNavigationPath.append(.game(gameID))
                        }
                    case .tournament:
                        CreateTournamentView { tournamentID in
                            createNavigationPath.append(.tournament(tournamentID))
                        }
                    case .practice:
                        CreatePracticeView { practiceID in
                            createNavigationPath.append(.practice(practiceID))
                        }
                    case .drafts:
                        DraftsBoardView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .appScreenBackground()
            .navigationTitle("Create")
            .onChange(of: availableTabs.map(\.id).joined(separator: ",")) { _ in
                if !availableTabs.contains(selectedTab) {
                    selectedTab = availableTabs.first ?? .game
                }
            }
            .navigationDestination(for: CreatedDestination.self) { destination in
                switch destination {
                case .game(let gameID):
                    if let game = appViewModel.createdGames.first(where: { $0.id == gameID }) {
                        GameDetailView(game: game)
                    } else {
                        Text("Created game not found")
                            .foregroundStyle(.secondary)
                    }
                case .tournament(let tournamentID):
                    TournamentDetailView(tournamentID: tournamentID)
                case .practice(let practiceID):
                    PracticeDetailView(practiceID: practiceID)
                }
            }
        }
    }
}

struct CreateGameView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let onCreated: (UUID) -> Void

    @State private var draft = GameDraft()
    @State private var showCreatedAlert = false
    @State private var createdMessage = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var permissionMessage: String?

    var body: some View {
        Form {
            Section("Game Creation") {
                Picker("Club location", selection: $draft.clubLocation) {
                    ForEach(ClubLocation.allCases) { location in
                        Text(location.rawValue).tag(location)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Club location")

                Toggle("Private game (invite link only)", isOn: $draft.isPrivateGame)
                Toggle("Court already booked", isOn: $draft.hasCourtBooked)
                Toggle("Save as draft", isOn: $draft.isDraft)
            }

            Section("Details") {
                DatePicker(
                    "Start at",
                    selection: $draft.startAt,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .accessibilityLabel("Start at")

                Stepper("Duration: \(draft.durationMinutes) min", value: $draft.durationMinutes, in: 30...240, step: 15)
                    .accessibilityHint("Adjust match duration in minutes")

                Picker("Format", selection: $draft.format) {
                    ForEach(MatchFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .accessibilityLabel("Match format")

                TextField("Location name", text: $draft.locationName)
                    .accessibilityLabel("Location name")

                TextField("Address (optional)", text: $draft.address)
                    .accessibilityLabel("Address")

                Stepper(
                    "Max players: \(draft.maxPlayers)",
                    value: $draft.maxPlayers,
                    in: draft.format.requiredPlayers...40
                )
                .accessibilityHint("Must be at least \(draft.format.requiredPlayers) for \(draft.format.rawValue)")
            }

            Section("Game Details") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Player rating range: \(draft.minElo) - \(draft.maxElo) Elo")
                        .font(.subheadline)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Min Elo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { Double(draft.minElo) },
                                set: { draft.minElo = min(Int($0), draft.maxElo) }
                            ),
                            in: 800...3000,
                            step: 25
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max Elo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { Double(draft.maxElo) },
                                set: { draft.maxElo = max(Int($0), draft.minElo) }
                            ),
                            in: 800...3000,
                            step: 25
                        )
                    }
                }

                Toggle("I am a player in this game", isOn: $draft.iAmPlaying)
                Toggle("Rating game (affects Elo)", isOn: $draft.isRatingGame)
            }

            Section("Game Management") {
                Toggle("Anyone can invite players", isOn: $draft.anyoneCanInvite)
                Toggle("Any player can input results", isOn: $draft.anyPlayerCanInputResults)
                Toggle("Entrance without confirmation", isOn: $draft.entranceWithoutConfirmation)
            }

            Section("Additional Comments") {
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 110)
                    .accessibilityLabel("Notes")
                    .accessibilityHint("Add what to bring and any game rules")
            }

            Section {
                Button {
                    switch appViewModel.createGame(from: draft) {
                    case .success(let created):
                        let mode = created.isDraft ? "Draft game" : "Game"
                        createdMessage = "\(mode) created at \(created.locationName) on \(DateFormatterService.tournamentDateTime.string(from: created.startAt))."
                        if let inviteLink = created.inviteLink {
                            createdMessage += "\nInvite link: \(inviteLink)"
                        }
                        if created.isDraft {
                            showCreatedAlert = true
                        } else {
                            onCreated(created.id)
                        }
                        draft = GameDraft()
                    case .failure(let error):
                        if case .unauthorized = error {
                            permissionMessage = AuthorizationUX.permissionDeniedMessage
                        } else {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                } label: {
                    Text(draft.isDraft ? "Save Game Draft" : "Create Game")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .appListBackground()
        .onChange(of: draft.format) { format in
            draft.maxPlayers = format.defaultMaxPlayers
        }
        .alert("Saved", isPresented: $showCreatedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(createdMessage)
        }
        .alert("Cannot Create Game", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .permissionDeniedAlert(message: $permissionMessage)
    }
}

private struct CreateTournamentView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let onCreated: (UUID) -> Void

    @State private var draft = TournamentDraft()
    @State private var showSavedAlert = false
    @State private var savedMessage = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Tournament") {
                TextField("Title", text: $draft.title)
                TextField("Location", text: $draft.location)
                DatePicker("Start at", selection: $draft.startAt, displayedComponents: [.date, .hourAndMinute])
                Toggle("Has end date", isOn: $draft.hasEndDate)
                if draft.hasEndDate {
                    DatePicker("End at", selection: $draft.endAt, displayedComponents: [.date, .hourAndMinute])
                }
                Picker("Visibility", selection: $draft.visibility) {
                    ForEach(TournamentVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.rawValue.capitalized).tag(visibility)
                    }
                }
                Picker("Format", selection: $draft.format) {
                    ForEach(MatchFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                Stepper("Max teams: \(draft.maxTeams)", value: $draft.maxTeams, in: 4...32)
                HStack {
                    Text("Entry fee")
                    Spacer()
                    TextField("0", value: $draft.entryFee, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
                Toggle("Save as draft", isOn: Binding(
                    get: { draft.status == .draft },
                    set: { draft.status = $0 ? .draft : .published }
                ))
            }

            Section("Notes") {
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 100)
            }

            Section {
                Button(draft.status == .draft ? "Save Tournament Draft" : "Create Tournament") {
                    switch appViewModel.createTournament(from: draft) {
                    case .success(let tournament):
                        if tournament.status == .draft {
                            savedMessage = "Tournament draft saved."
                            showSavedAlert = true
                        } else {
                            onCreated(tournament.id)
                        }
                        draft = TournamentDraft()
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .appListBackground()
        .alert("Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(savedMessage)
        }
        .alert("Cannot Save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

private struct CreatePracticeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let onCreated: (UUID) -> Void

    @State private var draft = PracticeDraft()
    @State private var showSavedAlert = false
    @State private var savedMessage = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Practice") {
                TextField("Title", text: $draft.title)
                TextField("Location", text: $draft.location)
                DatePicker("Start at", selection: $draft.startAt, displayedComponents: [.date, .hourAndMinute])
                Stepper("Duration: \(draft.durationMinutes) min", value: $draft.durationMinutes, in: 30...240, step: 15)
                Stepper("Players: \(draft.numberOfPlayers)", value: $draft.numberOfPlayers, in: 2...60)
                Toggle("Open join", isOn: $draft.isOpenJoin)
                Toggle("Save as draft", isOn: $draft.isDraft)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Elo range: \(draft.minElo) - \(draft.maxElo)")
                        .font(.subheadline)
                    Slider(
                        value: Binding(
                            get: { Double(draft.minElo) },
                            set: { draft.minElo = min(Int($0), draft.maxElo) }
                        ),
                        in: 800...3000,
                        step: 25
                    )
                    Slider(
                        value: Binding(
                            get: { Double(draft.maxElo) },
                            set: { draft.maxElo = max(Int($0), draft.minElo) }
                        ),
                        in: 800...3000,
                        step: 25
                    )
                }
                TextField("Focus area", text: $draft.focusArea)
            }

            Section("Notes") {
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 100)
            }

            Section {
                Button(draft.isDraft ? "Save Practice Draft" : "Create Practice") {
                    switch appViewModel.createPractice(from: draft) {
                    case .success(let practice):
                        if draft.isDraft {
                            savedMessage = "Practice draft saved."
                            showSavedAlert = true
                        } else {
                            onCreated(practice.id)
                        }
                        draft = PracticeDraft()
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .appListBackground()
        .alert("Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(savedMessage)
        }
        .alert("Cannot Save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

private struct DraftsBoardView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    private var showTournamentDrafts: Bool {
        appViewModel.currentUser?.isOrganizerActive == true || appViewModel.currentUser?.isAdmin == true
    }

    private var showPracticeDrafts: Bool {
        appViewModel.currentUser?.isCoachActive == true || appViewModel.currentUser?.isAdmin == true
    }

    var body: some View {
        List {
            Section("Game Drafts") {
                if appViewModel.currentUserGameDrafts.isEmpty {
                    Text("No game drafts")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appViewModel.currentUserGameDrafts) { game in
                        NavigationLink {
                            EditGameDraftView(game: game)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(game.locationName)
                                    .font(.headline)
                                Text(DateFormatterService.tournamentDateTime.string(from: game.startAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Players: \(game.players.count)/\(game.maxPlayers)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if showTournamentDrafts {
                Section("Tournament Drafts") {
                    if appViewModel.currentUserTournamentDrafts.isEmpty {
                        Text("No tournament drafts")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appViewModel.currentUserTournamentDrafts) { tournament in
                            NavigationLink {
                                EditTournamentDraftView(tournament: tournament)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tournament.title)
                                        .font(.headline)
                                    Text(DateFormatterService.tournamentDateTime.string(from: tournament.startDate))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(tournament.location)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            if showPracticeDrafts {
                Section("Practice Drafts") {
                    if appViewModel.currentUserPracticeDrafts.isEmpty {
                        Text("No practice drafts")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appViewModel.currentUserPracticeDrafts) { practice in
                            NavigationLink {
                                EditPracticeDraftView(practice: practice)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(practice.title)
                                        .font(.headline)
                                    Text(DateFormatterService.tournamentDateTime.string(from: practice.startDate))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(practice.location)
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

private struct EditGameDraftView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let game: CreatedGame

    @State private var draft: GameDraft
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    init(game: CreatedGame) {
        self.game = game
        _draft = State(initialValue: GameDraft(from: game))
    }

    var body: some View {
        Form {
            Section("Game Creation") {
                Picker("Club location", selection: $draft.clubLocation) {
                    ForEach(ClubLocation.allCases) { location in
                        Text(location.rawValue).tag(location)
                    }
                }
                .pickerStyle(.menu)
                Toggle("Private game (invite link only)", isOn: $draft.isPrivateGame)
                Toggle("Court already booked", isOn: $draft.hasCourtBooked)
            }

            Section("Details") {
                DatePicker("Start at", selection: $draft.startAt, displayedComponents: [.date, .hourAndMinute])
                Stepper("Duration: \(draft.durationMinutes) min", value: $draft.durationMinutes, in: 30...240, step: 15)
                Picker("Format", selection: $draft.format) {
                    ForEach(MatchFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                TextField("Location name", text: $draft.locationName)
                TextField("Address (optional)", text: $draft.address)
                Stepper("Max players: \(draft.maxPlayers)", value: $draft.maxPlayers, in: draft.format.requiredPlayers...40)
            }

            Section("Game Details") {
                Toggle("I am a player in this game", isOn: $draft.iAmPlaying)
                Toggle("Rating game (affects Elo)", isOn: $draft.isRatingGame)
                Toggle("Anyone can invite players", isOn: $draft.anyoneCanInvite)
                Toggle("Any player can input results", isOn: $draft.anyPlayerCanInputResults)
                Toggle("Entrance without confirmation", isOn: $draft.entranceWithoutConfirmation)
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 90)
            }

            Section {
                Button("Save Draft") {
                    var updated = draft
                    updated.isDraft = true
                    save(updated)
                }
                .buttonStyle(.bordered)

                Button("Publish") {
                    var updated = draft
                    updated.isDraft = false
                    save(updated)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .appListBackground()
        .navigationTitle("Edit Game Draft")
        .alert("Draft", isPresented: Binding(
            get: { savedMessage != nil },
            set: { if !$0 { savedMessage = nil } }
        )) {
            Button("OK") { dismiss() }
        } message: {
            Text(savedMessage ?? "")
        }
        .alert("Cannot Save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save(_ updatedDraft: GameDraft) {
        switch appViewModel.updateGameDraft(gameID: game.id, draft: updatedDraft) {
        case .success(let updated):
            savedMessage = updated.isDraft ? "Draft saved." : "Game published."
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

private struct EditTournamentDraftView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let tournament: Tournament

    @State private var draft: TournamentDraft
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    init(tournament: Tournament) {
        self.tournament = tournament
        _draft = State(initialValue: TournamentDraft(from: tournament))
    }

    var body: some View {
        Form {
            Section("Tournament") {
                TextField("Title", text: $draft.title)
                TextField("Location", text: $draft.location)
                DatePicker("Start at", selection: $draft.startAt, displayedComponents: [.date, .hourAndMinute])
                Toggle("Has end date", isOn: $draft.hasEndDate)
                if draft.hasEndDate {
                    DatePicker("End at", selection: $draft.endAt, displayedComponents: [.date, .hourAndMinute])
                }
                Picker("Visibility", selection: $draft.visibility) {
                    ForEach(TournamentVisibility.allCases, id: \.self) { visibility in
                        Text(visibility.rawValue.capitalized).tag(visibility)
                    }
                }
                Picker("Format", selection: $draft.format) {
                    ForEach(MatchFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                Stepper("Max teams: \(draft.maxTeams)", value: $draft.maxTeams, in: 4...32)
                HStack {
                    Text("Entry fee")
                    Spacer()
                    TextField("0", value: $draft.entryFee, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 90)
            }

            Section {
                Button("Save Draft") {
                    var updated = draft
                    updated.status = .draft
                    save(updated)
                }
                .buttonStyle(.bordered)

                Button("Publish") {
                    var updated = draft
                    updated.status = .published
                    save(updated)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .appListBackground()
        .navigationTitle("Edit Tournament Draft")
        .alert("Draft", isPresented: Binding(
            get: { savedMessage != nil },
            set: { if !$0 { savedMessage = nil } }
        )) {
            Button("OK") { dismiss() }
        } message: {
            Text(savedMessage ?? "")
        }
        .alert("Cannot Save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save(_ updatedDraft: TournamentDraft) {
        switch appViewModel.updateTournamentDraft(tournamentID: tournament.id, draft: updatedDraft) {
        case .success(let updated):
            savedMessage = updated.status == .draft ? "Draft saved." : "Tournament published."
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

private struct EditPracticeDraftView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    let practice: PracticeSession

    @State private var draft: PracticeDraft
    @State private var errorMessage: String?
    @State private var savedMessage: String?

    init(practice: PracticeSession) {
        self.practice = practice
        _draft = State(initialValue: PracticeDraft(from: practice))
    }

    var body: some View {
        Form {
            Section("Practice") {
                TextField("Title", text: $draft.title)
                TextField("Location", text: $draft.location)
                DatePicker("Start at", selection: $draft.startAt, displayedComponents: [.date, .hourAndMinute])
                Stepper("Duration: \(draft.durationMinutes) min", value: $draft.durationMinutes, in: 30...240, step: 15)
                Stepper("Players: \(draft.numberOfPlayers)", value: $draft.numberOfPlayers, in: 2...60)
                Toggle("Open join", isOn: $draft.isOpenJoin)
                TextField("Focus area", text: $draft.focusArea)
                TextEditor(text: $draft.notes)
                    .frame(minHeight: 90)
            }

            Section {
                Button("Save Draft") {
                    var updated = draft
                    updated.isDraft = true
                    save(updated)
                }
                .buttonStyle(.bordered)

                Button("Publish") {
                    var updated = draft
                    updated.isDraft = false
                    save(updated)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .appListBackground()
        .navigationTitle("Edit Practice Draft")
        .alert("Draft", isPresented: Binding(
            get: { savedMessage != nil },
            set: { if !$0 { savedMessage = nil } }
        )) {
            Button("OK") { dismiss() }
        } message: {
            Text(savedMessage ?? "")
        }
        .alert("Cannot Save", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save(_ updatedDraft: PracticeDraft) {
        switch appViewModel.updatePracticeDraft(sessionID: practice.id, draft: updatedDraft) {
        case .success(let updated):
            savedMessage = updated.isDraft ? "Draft saved." : "Practice published."
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}

private extension GameDraft {
    init(from game: CreatedGame) {
        self.clubLocation = game.clubLocation
        self.startAt = game.startAt
        self.durationMinutes = game.durationMinutes
        self.format = game.format
        self.locationName = game.locationName
        self.address = game.address
        self.maxPlayers = game.maxPlayers
        self.isPrivateGame = game.isPrivateGame
        self.hasCourtBooked = game.hasCourtBooked
        self.minElo = game.minElo
        self.maxElo = game.maxElo
        self.iAmPlaying = game.iAmPlaying
        self.isRatingGame = game.isRatingGame
        self.anyoneCanInvite = game.anyoneCanInvite
        self.anyPlayerCanInputResults = game.anyPlayerCanInputResults
        self.entranceWithoutConfirmation = game.entranceWithoutConfirmation
        self.isDraft = game.isDraft
        self.notes = game.notes
    }
}

private extension TournamentDraft {
    init(from tournament: Tournament) {
        self.title = tournament.title
        self.location = tournament.location
        self.startAt = tournament.startDate
        self.hasEndDate = tournament.endDate != nil
        self.endAt = tournament.endDate ?? Calendar.current.date(byAdding: .day, value: 1, to: tournament.startDate) ?? tournament.startDate
        self.visibility = tournament.visibility
        self.status = tournament.status
        self.format = MatchFormat(rawValue: tournament.format) ?? .fiveVFive
        self.maxTeams = tournament.maxTeams
        self.entryFee = tournament.entryFee
        self.notes = ""
    }
}

private extension PracticeDraft {
    init(from practice: PracticeSession) {
        self.title = practice.title
        self.location = practice.location
        self.startAt = practice.startDate
        self.durationMinutes = practice.durationMinutes
        self.numberOfPlayers = practice.numberOfPlayers
        self.minElo = practice.minElo
        self.maxElo = practice.maxElo
        self.isOpenJoin = practice.isOpenJoin
        self.isDraft = practice.isDraft
        self.focusArea = practice.focusArea
        self.notes = practice.notes
    }
}
