import SwiftUI

struct TournamentDetailView: View {
    private enum TournamentTab: String, CaseIterable, Identifiable {
        case standings = "Таблица"
        case matches = "Матчи"
        case teams = "Команды"

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
                            Label("Формат: \(tournament.format)", systemImage: "list.bullet.rectangle")
                            Label("Взнос: $\(Int(tournament.entryFee))", systemImage: "creditcard")
                        }
                        .font(.subheadline)

                        if appViewModel.canCurrentUserEditTournament(tournament) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Создать команду и записаться")
                                    .font(.headline)
                                TextField("Название команды", text: $teamName)
                                    .textFieldStyle(.roundedBorder)

                                Button("Создать команду") {
                                    appViewModel.createTeamAndJoinTournament(tournamentID: tournament.id, teamName: teamName)
                                    teamName = ""
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        Picker("Раздел турнира", selection: $selectedTab) {
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

                        organiserToolsSection(tournament)
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Турнир не найден")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Запись")
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
                        startTime: startTime
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
        .alert("Действие турнира", isPresented: tournamentActionAlertBinding) {
            Button("ОК", role: .cancel) {}
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
                Text("Инструменты организатора")
                    .font(.headline)

                if appViewModel.canCurrentUserEditTournament(tournament) {
                    Button("Редактировать турнир") {
                        isEditDetailsSheetPresented = true
                    }
                    .buttonStyle(.borderedProminent)

                    HStack(spacing: 8) {
                        TextField("Название новой команды", text: $organiserTeamName)
                            .textFieldStyle(.roundedBorder)

                        Button("Добавить") {
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
                                Button("Удалить", role: .destructive) {
                                    appViewModel.removeTeamFromTournament(tournamentID: tournament.id, teamID: team.id)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Button("Создать / изменить расписание") {
                        isScheduleSheetPresented = true
                    }
                    .buttonStyle(.bordered)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Разрешение споров (заглушка)")
                            .font(.subheadline.bold())
                        Picker("Статус спора", selection: disputeStatusBinding(for: tournament)) {
                            ForEach(TournamentDisputeStatus.allCases, id: \.self) { status in
                                Text(localizedDisputeStatus(status)).tag(status)
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
            Text("Таблица")
                .font(.headline)

            ForEach(Array(standings.enumerated()), id: \.element.id) { index, row in
                HStack {
                    Text("#\(index + 1)")
                        .font(.caption.bold())
                        .frame(width: 30, alignment: .leading)
                    Text(row.teamName)
                        .font(.subheadline.bold())
                    Spacer()
                    Text("И \(row.played)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("РМ \(row.goalDifference)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(row.points) очк")
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
            Text("Матчи")
                .font(.headline)

            if tournament.matches.isEmpty {
                Text("Матчи пока не запланированы")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tournament.matches) { match in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(teamName(for: match.homeTeamId, in: tournament)) против \(teamName(for: match.awayTeamId, in: tournament))")
                            .font(.subheadline.bold())
                        Text(DateFormatterService.tournamentDateTime.string(from: match.startTime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if match.isCompleted, let home = match.homeScore, let away = match.awayScore {
                            Text("Результат: \(home) - \(away)")
                                .font(.caption)
                        } else {
                            Text("Результат: Ожидается")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let game = appViewModel.createdGame(for: match.id) {
                            NavigationLink {
                                GameDetailView(game: game)
                            } label: {
                                Text("Открыть экран игры")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        if appViewModel.canCurrentUserEnterTournamentResult(tournament) {
                            Button("Внести / изменить результат") {
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
            Text("Команды")
                .font(.headline)

            if tournament.teams.count < 4 {
                Text("Для лиги рекомендуется минимум 4 команды.")
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
                                Text("Нет игроков")
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
        tournament.teams.first(where: { $0.id == teamID })?.name ?? "Неизвестная команда"
    }

    private func isCurrentUserInDifferentTeam(teamID: UUID, tournament: Tournament) -> Bool {
        guard let currentUserID = appViewModel.currentUser?.id else {
            return false
        }

        return tournament.teams.contains { team in
            team.id != teamID && team.members.contains(where: { $0.id == currentUserID })
        }
    }

    private func localizedDisputeStatus(_ status: TournamentDisputeStatus) -> String {
        switch status {
        case .none: return "Нет"
        case .open: return "Открыт"
        case .resolved: return "Решен"
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
            return "Покинуть команду"
        }
        return team.isFull ? "Команда заполнена" : "Вступить в команду"
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
                TextField("Название", text: $title)
                TextField("Локация", text: $location)
                DatePicker("Дата начала", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                TextField("Формат", text: $format)
                Stepper("Макс. команд: \(maxTeams)", value: $maxTeams, in: 2...64)
            }
            .navigationTitle("Редактировать турнир")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
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
                Picker("Домашняя команда", selection: $homeTeamId) {
                    ForEach(tournament.teams) { team in
                        Text(team.name).tag(Optional(team.id))
                    }
                }
                Picker("Гостевая команда", selection: $awayTeamId) {
                    ForEach(tournament.teams) { team in
                        Text(team.name).tag(Optional(team.id))
                    }
                }
                DatePicker("Начало матча", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
            }
            .navigationTitle("Запланировать матч")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
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
                Stepper("Счет хозяев: \(homeScore)", value: $homeScore, in: 0...50)
                Stepper("Счет гостей: \(awayScore)", value: $awayScore, in: 0...50)
            }
            .navigationTitle("Внести результат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(homeScore, awayScore)
                        dismiss()
                    }
                }
            }
        }
    }
}
