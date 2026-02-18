import SwiftUI

struct MatchDetailsView: View {
    private enum ParticipantSection: String, CaseIterable, Identifiable {
        case going
        case maybe
        case invited
        case waitlist
        case declined

        var id: String { rawValue }

        var title: String {
            switch self {
            case .going: return "Иду"
            case .maybe: return "Возможно"
            case .invited: return "Приглашен"
            case .waitlist: return "Лист ожидания"
            case .declined: return "Отказался"
            }
        }

        var status: RSVPStatus {
            switch self {
            case .going: return .going
            case .maybe: return .maybe
            case .invited: return .invited
            case .waitlist: return .waitlisted
            case .declined: return .declined
            }
        }
    }

    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel: MatchDetailsViewModel
    @State private var isAddEventSheetPresented = false
    @State private var selectedSection: ParticipantSection = .going
    @State private var isEditSheetPresented = false
    @State private var isInviteSheetPresented = false
    @State private var isFinalScoreSheetPresented = false
    @State private var isCancelMatchConfirmationPresented = false

    init(match: Match) {
        _viewModel = StateObject(wrappedValue: MatchDetailsViewModel(match: match))
    }

    private var participantsByID: [UUID: Participant] {
        Dictionary(uniqueKeysWithValues: viewModel.match.participants.map { ($0.id, $0) })
    }

    private var currentUserStatus: RSVPStatus? {
        guard let userId = appViewModel.currentUser?.id else { return nil }
        return participantsByID[userId]?.rsvpStatus
    }

    private var currentUserRoleTags: [String] {
        guard let currentUser = appViewModel.currentUser else { return [] }
        return RoleTagProvider.tags(for: currentUser, in: viewModel.match)
    }

    private var localizedMatchStatus: String {
        switch viewModel.match.status {
        case .scheduled: return "Запланирован"
        case .completed: return "Завершен"
        case .cancelled: return "Отменен"
        }
    }

    var body: some View {
        Group {
            if viewModel.isDeleted {
                VStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Матч удален")
                        .font(.headline)
                    Text("Этот матч был отменен и удален.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        scoreHeader
                        matchInfoCard
                        rsvpActionsCard
                        participantsCard
                        organiserToolsCard

                        NavigationLink {
                            MatchSummaryView(match: viewModel.match)
                        } label: {
                            HStack {
                                Text("Открыть сводку матча")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            GameTeamsView(viewModel: viewModel)
                                .environmentObject(appViewModel)
                        } label: {
                            HStack {
                                Text("Открыть команды")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        HStack {
                            Text("Лента событий")
                                .font(.title3.bold())
                            Spacer()
                            Button {
                                isAddEventSheetPresented = true
                            } label: {
                                Label("Добавить событие", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!viewModel.canCurrentUserEnterMatchResult)
                        }

                        if !viewModel.canCurrentUserEnterMatchResult {
                            Text("Только админы и организаторы матча могут вносить результат.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        EventsTimeline(events: viewModel.match.events, participantsByID: participantsByID)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Детали матча")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isAddEventSheetPresented) {
            AddEventSheet(participants: viewModel.match.participants) { newEvent in
                viewModel.addEvent(newEvent)
            }
        }
        .sheet(isPresented: $isEditSheetPresented) {
            MatchEditSheet(match: viewModel.match) { startAt, location, format, maxPlayers, notes in
                viewModel.updateMatchDetails(
                    startTime: startAt,
                    location: location,
                    format: format,
                    maxPlayers: maxPlayers,
                    notes: notes
                )
            }
        }
        .sheet(isPresented: $isInviteSheetPresented) {
            InvitePlayerSheet(inviteLink: viewModel.inviteLink) { name, elo in
                viewModel.inviteParticipant(name: name, elo: elo)
            }
        }
        .sheet(isPresented: $isFinalScoreSheetPresented) {
            FinalScoreSheet { home, away in
                viewModel.completeMatch(finalHomeScore: home, finalAwayScore: away)
            }
        }
        .task {
            viewModel.setCurrentUser(appViewModel.currentUser)
            viewModel.loadPersistedState()
        }
        .onChange(of: viewModel.match.status) { _ in
            appViewModel.refreshGameLists()
        }
        .alert("Обновление RSVP", isPresented: messageBinding) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(viewModel.toastMessage ?? "")
        }
        .alert("Отмена матча", isPresented: $isCancelMatchConfirmationPresented) {
            Button("Оставить матч", role: .cancel) {}
            Button("Удалить матч", role: .destructive) {
                viewModel.cancelMatch()
                _ = appViewModel.deleteGameAsOrganiserOrAdmin(gameId: viewModel.match.id)
            }
        } message: {
            Text("Вы уверены, что хотите отменить матч?")
        }
        .permissionDeniedAlert(message: $viewModel.toastMessage)
    }

    private var scoreHeader: some View {
        let score = viewModel.match.scoreline

        return VStack(alignment: .leading, spacing: 10) {
            RoleBadge(tags: currentUserRoleTags, size: .medium)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.match.homeTeam.name)
                        .font(.headline)
                    Text("\(score.home)")
                        .font(.system(size: 32, weight: .bold))
                }

                Spacer()

                Text(":")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(viewModel.match.awayTeam.name)
                        .font(.headline)
                    Text("\(score.away)")
                        .font(.system(size: 32, weight: .bold))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var matchInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(DateFormatterService.tournamentDateTime.string(from: viewModel.match.startTime), systemImage: "clock")
            Label(viewModel.match.location, systemImage: "mappin.and.ellipse")
            Label(viewModel.match.isRatingGame ? "Рейтинговый матч" : "Не рейтинговый матч", systemImage: "chart.line.uptrend.xyaxis")
            Label(viewModel.match.isFieldBooked ? "Поле забронировано" : "Поле не забронировано", systemImage: "sportscourt")
            Label("Формат: \(viewModel.match.format)", systemImage: "rectangle.3.group")
            Label("Статус: \(localizedMatchStatus)", systemImage: "flag")
            Label("Свободных мест: \(viewModel.spotsLeft)", systemImage: "person.badge.plus")
            Label("Лист ожидания: \(viewModel.waitlistCount)", systemImage: "clock.badge.exclamationmark")
            if !viewModel.match.notes.isEmpty {
                Label(viewModel.match.notes, systemImage: "note.text")
            }
        }
        .font(.subheadline)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var rsvpActionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ваш RSVP")
                .font(.headline)

            Text("Текущий: \(currentUserStatus?.title ?? "Не приглашен")")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Я иду") {
                    updateCurrentUserRSVP(to: .going)
                }
                .buttonStyle(.borderedProminent)
                .disabled(appViewModel.currentUser == nil)

                Button("Возможно") {
                    updateCurrentUserRSVP(to: .maybe)
                }
                .buttonStyle(.bordered)
                .disabled(appViewModel.currentUser == nil)

                Button("Отказаться") {
                    updateCurrentUserRSVP(to: .declined)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(appViewModel.currentUser == nil)
            }

            if appViewModel.currentUser == nil {
                Text("Войдите, чтобы ответить на приглашение.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Участники")
                .font(.headline)

            Picker("RSVP", selection: $selectedSection) {
                ForEach(ParticipantSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)

            let filteredParticipants = viewModel.participants(for: selectedSection.status)

            if filteredParticipants.isEmpty {
                Text("Нет игроков в \(selectedSection.title.lowercased())")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(filteredParticipants) { participant in
                    HStack {
                        PlayerAvatarView(
                            name: participant.name,
                            imageData: avatarData(for: participant),
                            size: 28
                        )
                        Text(participant.name)
                        Spacer()
                        Text("Elo \(participant.elo)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var organiserToolsCard: some View {
        Group {
            if viewModel.canCurrentUserEditMatch || viewModel.canCurrentUserInviteToMatch || viewModel.canCurrentUserEnterMatchResult {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Инструменты организатора")
                        .font(.headline)

                    HStack(spacing: 8) {
                        if viewModel.canCurrentUserEditMatch {
                            Button("Редактировать матч") {
                                isEditSheetPresented = true
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if viewModel.canCurrentUserInviteToMatch {
                            Button("Пригласить/Поделиться") {
                                isInviteSheetPresented = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if viewModel.canCurrentUserEditMatch {
                        Text("Управление участниками")
                            .font(.subheadline.bold())

                        ForEach(viewModel.match.participants) { participant in
                            HStack {
                                PlayerAvatarView(
                                    name: participant.name,
                                    imageData: avatarData(for: participant),
                                    size: 24
                                )
                                Text(participant.name)
                                    .lineLimit(1)
                                Spacer()
                                Button("Лист ожидания") {
                                    viewModel.moveParticipantToWaitlist(participantId: participant.id)
                                }
                                .buttonStyle(.bordered)

                                Button("Удалить", role: .destructive) {
                                    viewModel.removeParticipant(participantId: participant.id)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        if viewModel.canCurrentUserEditMatch {
                            Button("Отмена матча", role: .destructive) {
                                isCancelMatchConfirmationPresented = true
                            }
                            .buttonStyle(.bordered)
                        }

                        if viewModel.canCurrentUserEnterMatchResult {
                            Button("Финальный счет") {
                                isFinalScoreSheetPresented = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { viewModel.toastMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.toastMessage = nil
                }
            }
        )
    }

    private func updateCurrentUserRSVP(to status: RSVPStatus) {
        guard let userId = appViewModel.currentUser?.id else {
            return
        }

        viewModel.setRSVP(for: userId, desiredStatus: status)
    }

    private func avatarData(for participant: Participant) -> Data? {
        appViewModel.users.first(where: { $0.id == participant.id })?.avatarImageData
    }
}

private struct MatchEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var startAt: Date
    @State private var location: String
    @State private var format: String
    @State private var maxPlayers: Int
    @State private var notes: String
    let onSave: (Date, String, String, Int, String) -> Void

    init(match: Match, onSave: @escaping (Date, String, String, Int, String) -> Void) {
        _startAt = State(initialValue: match.startTime)
        _location = State(initialValue: match.location)
        _format = State(initialValue: match.format)
        _maxPlayers = State(initialValue: match.maxPlayers)
        _notes = State(initialValue: match.notes)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Время начала", selection: $startAt, displayedComponents: [.date, .hourAndMinute])
                TextField("Локация", text: $location)
                TextField("Формат", text: $format)
                Stepper("Макс. игроков: \(maxPlayers)", value: $maxPlayers, in: 1...40)
                TextField("Заметки", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("Редактировать матч")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        onSave(startAt, location, format, maxPlayers, notes)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct InvitePlayerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let inviteLink: String
    let onInvite: (String, Int) -> Void

    @State private var playerName = ""
    @State private var elo = 1400

    var body: some View {
        NavigationStack {
            Form {
                Section("Поделиться ссылкой") {
                    Text(inviteLink)
                        .font(.footnote)
                        .textSelection(.enabled)
                    ShareLink(item: inviteLink) {
                        Label("Поделиться ссылкой", systemImage: "square.and.arrow.up")
                    }
                }

                Section("Пригласить игрока") {
                    TextField("Имя игрока", text: $playerName)
                    Stepper("Elo: \(elo)", value: $elo, in: 800...3000, step: 25)
                }
            }
            .navigationTitle("Приглашение игроков")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Пригласить") {
                        onInvite(playerName, elo)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct FinalScoreSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var homeScore = 0
    @State private var awayScore = 0
    let onSave: (Int, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Stepper("Счет хозяев: \(homeScore)", value: $homeScore, in: 0...50)
                Stepper("Счет гостей: \(awayScore)", value: $awayScore, in: 0...50)
            }
            .navigationTitle("Финальный счет")
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

struct EventsTimeline: View {
    let events: [MatchEvent]
    let participantsByID: [UUID: Participant]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if events.isEmpty {
                Text("Пока нет событий")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(events.sorted { $0.minute < $1.minute }) { event in
                    HStack(spacing: 10) {
                        Text("\(event.minute)'")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .leading)

                        Image(systemName: event.type.iconName)
                            .foregroundStyle(eventColor(event.type))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.type.title)
                                .font(.subheadline.bold())
                            Text(participantsByID[event.playerId]?.name ?? "Неизвестный игрок")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func eventColor(_ type: MatchEventType) -> Color {
        switch type {
        case .goal:
            return .green
        case .assist:
            return .blue
        case .yellow:
            return .yellow
        case .red:
            return .red
        case .save:
            return .mint
        }
    }
}

struct AddEventSheet: View {
    let participants: [Participant]
    let onAdd: (MatchEvent) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var type: MatchEventType = .goal
    @State private var minute: Int = 1
    @State private var playerId: UUID?
    @State private var createdById: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Событие") {
                    Picker("Тип", selection: $type) {
                        ForEach(MatchEventType.allCases) { eventType in
                            Text(eventType.title).tag(eventType)
                        }
                    }

                    Stepper("Минута: \(minute)", value: $minute, in: 1...120)
                }

                Section("Игроки") {
                    Picker("Игрок", selection: playerSelectionBinding) {
                        ForEach(participants) { participant in
                            Text(participant.name).tag(Optional(participant.id))
                        }
                    }

                    Picker("Создано", selection: createdBySelectionBinding) {
                        ForEach(participants) { participant in
                            Text(participant.name).tag(Optional(participant.id))
                        }
                    }
                }
            }
            .navigationTitle("Добавить событие матча")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        guard let playerId, let createdById else { return }
                        onAdd(
                            MatchEvent(
                                id: UUID(),
                                type: type,
                                minute: minute,
                                playerId: playerId,
                                createdById: createdById,
                                createdAt: Date()
                            )
                        )
                        dismiss()
                    }
                    .disabled(playerId == nil || createdById == nil)
                }
            }
            .onAppear {
                if playerId == nil { playerId = participants.first?.id }
                if createdById == nil { createdById = participants.first?.id }
            }
        }
    }

    private var playerSelectionBinding: Binding<UUID?> {
        Binding(get: { playerId }, set: { playerId = $0 })
    }

    private var createdBySelectionBinding: Binding<UUID?> {
        Binding(get: { createdById }, set: { createdById = $0 })
    }
}

struct MatchSummaryView: View {
    let match: Match

    private var summaryRows: [MatchSummaryRow] {
        MatchStatsAggregator.summaryRows(participants: match.participants, events: match.events)
    }

    var body: some View {
        List(summaryRows) { row in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(row.participant.name)
                        .font(.headline)
                    Spacer()
                    Text("Elo \(row.participant.elo)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    statBadge(label: "G", value: row.stats.goals, color: .green)
                    statBadge(label: "A", value: row.stats.assists, color: .blue)
                    statBadge(label: "Y", value: row.stats.yellowCards, color: .yellow)
                    statBadge(label: "R", value: row.stats.redCards, color: .red)
                    statBadge(label: "S", value: row.stats.saves, color: .mint)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Сводка матча")
    }

    private func statBadge(label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.bold())
            Text("\(value)")
                .font(.caption.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: Capsule())
    }
}

struct MatchDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let appViewModel = AppViewModel()
        let users = MockDataService.seedUsers()
        appViewModel.currentUser = users.first

        return NavigationStack {
            MatchDetailsView(match: makePreviewMatch())
                .environmentObject(appViewModel)
        }
    }

    private static func makePreviewMatch() -> Match {
        let users = MockDataService.seedUsers()
        let homeUsers = Array(users.prefix(2))
        let awayUsers = Array(users.dropFirst(2).prefix(2))

        let homeTeam = Team(id: UUID(), name: "Blue FC", members: homeUsers, maxPlayers: 5)
        let awayTeam = Team(id: UUID(), name: "Red FC", members: awayUsers, maxPlayers: 5)

        let participants = (homeUsers.map {
            Participant(id: $0.id, name: $0.fullName, teamId: homeTeam.id, elo: $0.eloRating, rsvpStatus: .going)
        }) + (awayUsers.map {
            Participant(id: $0.id, name: $0.fullName, teamId: awayTeam.id, elo: $0.eloRating, rsvpStatus: .invited)
        })

        let now = Date()
        let first = participants[0]
        let second = participants[1]
        let third = participants[2]
        let ownerId = participants.last?.id ?? UUID()

        return Match(
            id: UUID(),
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            participants: participants,
            events: [
                MatchEvent(id: UUID(), type: .goal, minute: 7, playerId: first.id, createdById: first.id, createdAt: now),
                MatchEvent(id: UUID(), type: .assist, minute: 7, playerId: second.id, createdById: first.id, createdAt: now),
                MatchEvent(id: UUID(), type: .yellow, minute: 23, playerId: third.id, createdById: second.id, createdAt: now)
            ],
            location: "Downtown Arena, Austin",
            startTime: now,
            isRatingGame: true,
            isFieldBooked: false,
            maxPlayers: 4,
            ownerId: ownerId,
            organiserIds: [ownerId]
        )
    }
}
