import SwiftUI

struct TournamentDetailView: View {
    private enum TournamentTab: String, CaseIterable, Identifiable {
        case standings = "Standings"
        case matches = "Matches"
        case teams = "Teams"

        var id: String { rawValue }
    }

    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var teamName = ""
    @State private var organiserTeamName = ""
    @State private var isEditDetailsSheetPresented = false
    @State private var isScheduleSheetPresented = false
    @State private var selectedMatchForResult: TournamentMatch?
    @State private var selectedTab: TournamentTab = .standings

    let tournamentID: UUID

    var tournament: Tournament? {
        appViewModel.visibleTournaments.first(where: { $0.id == tournamentID })
    }

    private var isTournamentClosed: Bool {
        guard let tournament else { return false }
        if tournament.status == .completed || tournament.status == .cancelled {
            return true
        }
        guard !tournament.matches.isEmpty else { return false }
        return tournament.matches.allSatisfy { $0.status == .completed || $0.status == .cancelled }
    }

    var body: some View {
        Group {
            if let tournament {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(tournament.title)
                            .font(.title2.bold())

                        VStack(alignment: .leading, spacing: 8) {
                            Label(tournament.location, systemImage: "mappin")
                            Label(DateFormatterService.tournamentDateTime.string(from: tournament.startDate), systemImage: "calendar")
                            Label("Format: \(tournament.format)", systemImage: "list.bullet.rectangle")
                            Label("Entry fee: $\(Int(tournament.entryFee))", systemImage: "creditcard")
                        }
                        .font(.subheadline)

                        if appViewModel.canCurrentUserEditTournament(tournament) && !isTournamentClosed {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Create Team & Book")
                                    .font(.headline)
                                TextField("Team name", text: $teamName)
                                    .textFieldStyle(.roundedBorder)

                                Button("Create Team") {
                                    appViewModel.createTeamAndJoinTournament(tournamentID: tournament.id, teamName: teamName)
                                    teamName = ""
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        Picker("Tournament section", selection: $selectedTab) {
                            ForEach(TournamentTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch selectedTab {
                        case .standings:
                            standingsSection(tournament)
                        case .matches:
                            matchesSection(tournament)
                        case .teams:
                            teamsSection(tournament)
                        }

                        if !isTournamentClosed {
                            organiserToolsSection(tournament)
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Tournament not found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Booking")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isEditDetailsSheetPresented) {
            if let tournament {
                EditTournamentDetailsSheet(tournament: tournament) { title, location, startDate, format, maxTeams in
                    appViewModel.updateTournamentDetails(
                        tournamentID: tournament.id,
                        title: title,
                        location: location,
                        startDate: startDate,
                        format: format,
                        maxTeams: maxTeams
                    )
                }
            }
        }
        .sheet(isPresented: $isScheduleSheetPresented) {
            if let tournament {
                ScheduleTournamentMatchSheet(tournament: tournament) { homeId, awayId, startTime in
                    appViewModel.createTournamentMatch(
                        tournamentID: tournament.id,
                        homeTeamID: homeId,
                        awayTeamID: awayId,
                        startTime: startTime,
                        locationName: tournament.location,
                        matchday: nil
                    )
                }
            }
        }
        .sheet(item: $selectedMatchForResult) { match in
            EnterTournamentResultSheet(match: match) { homeScore, awayScore in
                appViewModel.updateTournamentMatchResult(
                    tournamentID: tournamentID,
                    matchID: match.id,
                    homeScore: homeScore,
                    awayScore: awayScore
                )
            }
        }
        .alert("Tournament Action", isPresented: tournamentActionAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appViewModel.tournamentActionMessage ?? "")
        }
        .permissionDeniedAlert(message: $appViewModel.tournamentActionMessage)
        .onAppear {
            appViewModel.syncTournamentMatchesToCreatedGames(tournamentID: tournamentID)
        }
    }

    @ViewBuilder
    private func organiserToolsSection(_ tournament: Tournament) -> some View {
        if appViewModel.canCurrentUserEditTournament(tournament) || appViewModel.canCurrentUserEnterTournamentResult(tournament) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Organiser Tools")
                    .font(.headline)

                if appViewModel.canCurrentUserEditTournament(tournament) {
                    Button("Edit Tournament Details") {
                        isEditDetailsSheetPresented = true
                    }
                    .buttonStyle(.borderedProminent)

                    HStack(spacing: 8) {
                        TextField("Add team name", text: $organiserTeamName)
                            .textFieldStyle(.roundedBorder)

                        Button("Add") {
                            appViewModel.addTeamToTournament(tournamentID: tournament.id, teamName: organiserTeamName)
                            organiserTeamName = ""
                        }
                        .buttonStyle(.bordered)
                    }

                    if !tournament.teams.isEmpty {
                        ForEach(tournament.teams) { team in
                            HStack {
                                Text(team.name)
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    appViewModel.removeTeamFromTournament(tournamentID: tournament.id, teamID: team.id)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Button("Create / Edit Schedule") {
                        isScheduleSheetPresented = true
                    }
                    .buttonStyle(.bordered)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Resolve Disputes (stub)")
                            .font(.subheadline.bold())
                        Picker("Dispute status", selection: disputeStatusBinding(for: tournament)) {
                            ForEach(TournamentDisputeStatus.allCases, id: \.self) { status in
                                Text(status.rawValue.capitalized).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func standingsSection(_ tournament: Tournament) -> some View {
        let standings = TournamentStandingsService.standings(for: tournament)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Standings")
                .font(.headline)

            ForEach(Array(standings.enumerated()), id: \.element.id) { index, row in
                HStack {
                    Text("#\(index + 1)")
                        .font(.caption.bold())
                        .frame(width: 30, alignment: .leading)
                    Text(row.teamName)
                        .font(.subheadline.bold())
                    Spacer()
                    Text("P \(row.played)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("GD \(row.goalDifference)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(row.points) pts")
                        .font(.caption.bold())
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func matchesSection(_ tournament: Tournament) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Matches")
                .font(.headline)

            if tournament.matches.isEmpty {
                Text("No matches scheduled yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tournament.matches) { match in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(teamName(for: match.homeTeamId, in: tournament)) vs \(teamName(for: match.awayTeamId, in: tournament))")
                            .font(.subheadline.bold())
                        Text(DateFormatterService.tournamentDateTime.string(from: match.startTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if match.isCompleted, let home = match.homeScore, let away = match.awayScore {
                            Text("Result: \(home) - \(away)")
                                .font(.caption)
                        } else {
                            Text("Result: Pending")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let game = appViewModel.createdGame(for: match.id) {
                            NavigationLink {
                                GameDetailView(game: game)
                            } label: {
                                Text("Open Game Screen")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        if appViewModel.canCurrentUserEnterTournamentResult(tournament) {
                            Button("Enter / Edit Result") {
                                selectedMatchForResult = match
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func teamsSection(_ tournament: Tournament) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Teams")
                .font(.headline)

            if tournament.teams.count < 4 {
                Text("League MVP works best with 4+ teams.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(tournament.teams) { team in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(team.name)
                            .font(.headline)
                        Spacer()
                        Text("\(team.members.count)/\(team.maxPlayers)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(PositionGroup.allCases) { group in
                        let members = groupedMembers(team.members, group: group)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            if members.isEmpty {
                                Text("No players")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(members) { member in
                                            HStack(spacing: 5) {
                                                PlayerAvatarView(
                                                    name: member.fullName,
                                                    imageData: member.avatarImageData,
                                                    size: 20
                                                )
                                                Text(member.fullName.components(separatedBy: " ").first ?? member.fullName)
                                                    .font(.caption2)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Button(teamActionTitle(for: team, in: tournament)) {
                        if isCurrentUserInTeam(teamID: team.id, tournament: tournament) {
                            appViewModel.leaveTeam(tournamentID: tournament.id, teamID: team.id)
                        } else {
                            appViewModel.joinTeam(tournamentID: tournament.id, teamID: team.id)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isTeamActionDisabled(for: team, in: tournament))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func groupedMembers(_ members: [User], group: PositionGroup) -> [User] {
        members.filter { playerPositionGroup($0) == group }
    }

    private func playerPositionGroup(_ user: User) -> PositionGroup {
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

    private func teamName(for teamID: UUID, in tournament: Tournament) -> String {
        tournament.teams.first(where: { $0.id == teamID })?.name ?? "Unknown Team"
    }

    private func isCurrentUserInDifferentTeam(teamID: UUID, tournament: Tournament) -> Bool {
        guard let currentUserID = appViewModel.currentUser?.id else {
            return false
        }

        return tournament.teams.contains { team in
            team.id != teamID && team.members.contains(where: { $0.id == currentUserID })
        }
    }

    private func isCurrentUserInTeam(teamID: UUID, tournament: Tournament) -> Bool {
        guard let currentUserID = appViewModel.currentUser?.id else {
            return false
        }

        return tournament.teams.contains { team in
            team.id == teamID && team.members.contains(where: { $0.id == currentUserID })
        }
    }

    private func teamActionTitle(for team: Team, in tournament: Tournament) -> String {
        if isCurrentUserInTeam(teamID: team.id, tournament: tournament) {
            return "Leave Team"
        }
        return team.isFull ? "Team Full" : "Join Team"
    }

    private func isTeamActionDisabled(for team: Team, in tournament: Tournament) -> Bool {
        if isCurrentUserInTeam(teamID: team.id, tournament: tournament) {
            return false
        }
        return team.isFull || isCurrentUserInDifferentTeam(teamID: team.id, tournament: tournament)
    }

    private func disputeStatusBinding(for tournament: Tournament) -> Binding<TournamentDisputeStatus> {
        Binding(
            get: { tournament.disputeStatus },
            set: { newStatus in
                appViewModel.resolveTournamentDispute(tournamentID: tournament.id, status: newStatus)
            }
        )
    }

    private var tournamentActionAlertBinding: Binding<Bool> {
        Binding(
            get: { appViewModel.tournamentActionMessage != nil },
            set: { isPresented in
                if !isPresented {
                    appViewModel.tournamentActionMessage = nil
                }
            }
        )
    }
}

private struct EditTournamentDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var location: String
    @State private var startDate: Date
    @State private var format: String
    @State private var maxTeams: Int
    let onSave: (String, String, Date, String, Int) -> Void

    init(tournament: Tournament, onSave: @escaping (String, String, Date, String, Int) -> Void) {
        _title = State(initialValue: tournament.title)
        _location = State(initialValue: tournament.location)
        _startDate = State(initialValue: tournament.startDate)
        _format = State(initialValue: tournament.format)
        _maxTeams = State(initialValue: tournament.maxTeams)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Location", text: $location)
                DatePicker("Start Date", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                TextField("Format", text: $format)
                Stepper("Max Teams: \(maxTeams)", value: $maxTeams, in: 2...64)
            }
            .navigationTitle("Edit Tournament")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, location, startDate, format, maxTeams)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ScheduleTournamentMatchSheet: View {
    @Environment(\.dismiss) private var dismiss

    let tournament: Tournament
    let onSave: (UUID, UUID, Date) -> Void

    @State private var homeTeamId: UUID?
    @State private var awayTeamId: UUID?
    @State private var startTime: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Picker("Home Team", selection: $homeTeamId) {
                    ForEach(tournament.teams) { team in
                        Text(team.name).tag(Optional(team.id))
                    }
                }
                Picker("Away Team", selection: $awayTeamId) {
                    ForEach(tournament.teams) { team in
                        Text(team.name).tag(Optional(team.id))
                    }
                }
                DatePicker("Match Start", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
            }
            .navigationTitle("Schedule Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let homeTeamId, let awayTeamId else { return }
                        onSave(homeTeamId, awayTeamId, startTime)
                        dismiss()
                    }
                    .disabled(homeTeamId == nil || awayTeamId == nil)
                }
            }
            .onAppear {
                homeTeamId = tournament.teams.first?.id
                awayTeamId = tournament.teams.dropFirst().first?.id ?? tournament.teams.first?.id
            }
        }
    }
}

private struct EnterTournamentResultSheet: View {
    @Environment(\.dismiss) private var dismiss

    let match: TournamentMatch
    let onSave: (Int, Int) -> Void

    @State private var homeScore: Int
    @State private var awayScore: Int

    init(match: TournamentMatch, onSave: @escaping (Int, Int) -> Void) {
        self.match = match
        self.onSave = onSave
        _homeScore = State(initialValue: match.homeScore ?? 0)
        _awayScore = State(initialValue: match.awayScore ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Stepper("Home Score: \(homeScore)", value: $homeScore, in: 0...50)
                Stepper("Away Score: \(awayScore)", value: $awayScore, in: 0...50)
            }
            .navigationTitle("Enter Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(homeScore, awayScore)
                        dismiss()
                    }
                }
            }
        }
    }
}
