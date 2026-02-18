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
                        Text("Профиль не загружен")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Профиль")
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
    @State private var preferredPositionSaveTask: Task<Void, Never>?
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
            Section("Профиль игрока") {
                RoleBadge(
                    tags: RoleTagProvider.tags(for: user, tournaments: appViewModel.visibleTournaments),
                    size: .medium
                )
                HStack(spacing: 12) {
                    PlayerAvatarView(
                        name: viewModel.name.isEmpty ? user.fullName : viewModel.name,
                        imageData: viewModel.avatarImageData,
                        size: 56
                    )

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Загрузить изображение", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.bordered)
                }
                TextField("Имя", text: $viewModel.name)
                TextField("Позиции (через запятую)", text: $viewModel.positionsText)
                TextField("Локация", text: $viewModel.location)

                NavigationLink {
                    PositionPickerView(selectedPositions: $viewModel.preferredPositions) { _ in
                        schedulePreferredPositionsAutosave()
                    }
                } label: {
                    HStack {
                        Text("Предпочитаемая позиция")
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

                Picker("Ведущая нога", selection: $viewModel.preferredFoot) {
                    ForEach(PreferredFoot.allCases) { foot in
                        Text(localizedFoot(foot)).tag(foot)
                    }
                }

                HStack {
                    Text("ELO")
                    Spacer()
                    Text("\(eloRating)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Создан")
                    Spacer()
                    Text(DateFormatterService.tournamentDateTime.string(from: viewModel.createdAt))
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }

            Section("Мини-статистика") {
                statRow(title: "Матчей сыграно", value: "\(viewModel.completedMatchesPlayed)")
                statRow(title: "Победы", value: "\(viewModel.winsCount)")
                statRow(title: "Ничьи", value: "\(viewModel.drawsCount)")
                statRow(title: "Поражения", value: "\(viewModel.lossesCount)")
            }

            Section("Мои матчи") {
                if viewModel.matchHistory.isEmpty {
                    Text(viewModel.isLoading ? "Загрузка матчей..." : "Пока нет матчей")
                        .foregroundStyle(.secondary)
                } else {
                    matchSubsection(title: "Предстоящие", matches: viewModel.upcomingMatches)
                    matchSubsection(title: "Прошедшие", matches: viewModel.pastMatches)
                }
            }

            Section("Игры") {
                if appViewModel.currentUserUpcomingCreatedGames.isEmpty && appViewModel.currentUserPastCreatedGames.isEmpty {
                    Text("Пока нет игр")
                        .foregroundStyle(.secondary)
                } else {
                    createdGameSubsection(title: "Предстоящие", games: appViewModel.currentUserUpcomingCreatedGames)
                    createdGameSubsection(title: "Прошедшие", games: appViewModel.currentUserPastCreatedGames)
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
                Button {
                    Task {
                        await persistProfileChanges()
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Сохранить профиль")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Выйти", role: .destructive) {
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
        .onDisappear {
            preferredPositionSaveTask?.cancel()
        }
        .onChange(of: selectedPhotoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.avatarImageData = data
                    await persistProfileChanges()
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
        return selected.isEmpty ? "Нет" : selected.joined(separator: " • ")
    }

    private func localizedFoot(_ foot: PreferredFoot) -> String {
        switch foot {
        case .left: return "Левая"
        case .right: return "Правая"
        case .both: return "Обе"
        }
    }

    private func matchSubsection(title: String, matches: [PlayerMatch]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.top, 2)

            if matches.isEmpty {
                Text("Нет матчей")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matches) { match in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(match.result)
                                .font(.headline)
                            Spacer()
                            Text(match.score)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("против \(match.opponent)")
                            .font(.subheadline)
                        Text(DateFormatterService.tournamentDateTime.string(from: match.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func createdGameSubsection(title: String, games: [CreatedGame]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.top, 2)

            if games.isEmpty {
                Text("Нет игр")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(games.prefix(5)) { game in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(game.locationName)
                                .font(.headline)
                            Spacer()
                            Text("Ср. Elo \(game.averageElo)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(DateFormatterService.tournamentDateTime.string(from: game.startAt))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Игроки: \(game.players.count)/\(game.maxPlayers)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func schedulePreferredPositionsAutosave() {
        preferredPositionSaveTask?.cancel()
        preferredPositionSaveTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await persistProfileChanges()
        }
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
            .previewDisplayName("Профиль")
    }

    private static var profileEditorPreview: some View {
        let user = MockDataService.seedUsers().first ?? User(
            id: UUID(),
            fullName: "Тестовый игрок",
            email: "preview@sportapp.test",
            favoritePosition: "Вингер",
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
            .navigationTitle("Профиль")
        }
        .previewDisplayName("Редактор профиля")
    }
}
