import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Главная", systemImage: "house")
                }

            TournamentsView()
                .tabItem {
                    Label("Играть", systemImage: "sportscourt")
                }

            LeaderboardView()
                .tabItem {
                    Label("Рейтинг", systemImage: "list.number")
                }

            CreateGameView()
                .tabItem {
                    Label("Создать", systemImage: "plus.circle")
                }

            ProfileView()
                .tabItem {
                    Label("Профиль", systemImage: "person")
                }

            if appViewModel.currentUser?.isAdmin == true {
                AdminView()
                    .tabItem {
                        Label("Админ", systemImage: "lock.shield")
                    }
            }
        }
    }
}

struct CreateGameView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var draft = GameDraft()
    @State private var showCreatedAlert = false
    @State private var createdMessage = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var permissionMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Создание игры") {
                    Picker("Клуб", selection: $draft.clubLocation) {
                        ForEach(ClubLocation.allCases) { location in
                            Text(location.rawValue).tag(location)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Клуб")

                    Toggle("Приватная игра (только по ссылке)", isOn: $draft.isPrivateGame)
                    Toggle("Поле уже забронировано", isOn: $draft.hasCourtBooked)
                }

                Section("Детали") {
                    DatePicker(
                        "Начало",
                        selection: $draft.startAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityLabel("Начало")

                    Stepper("Длительность: \(draft.durationMinutes) мин", value: $draft.durationMinutes, in: 30...240, step: 15)
                        .accessibilityHint("Измените длительность матча в минутах")

                    Picker("Формат", selection: $draft.format) {
                        ForEach(MatchFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .accessibilityLabel("Формат матча")

                    TextField("Название локации", text: $draft.locationName)
                        .accessibilityLabel("Название локации")

                    TextField("Адрес (необязательно)", text: $draft.address)
                        .accessibilityLabel("Адрес")

                    Stepper(
                        "Макс. игроков: \(draft.maxPlayers)",
                        value: $draft.maxPlayers,
                        in: draft.format.requiredPlayers...40
                    )
                    .accessibilityHint("Минимум \(draft.format.requiredPlayers) для \(draft.format.rawValue)")
                }

                Section("Детали игры") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Диапазон рейтинга игроков: \(draft.minElo) - \(draft.maxElo) ELO")
                            .font(.subheadline)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Мин. ELO")
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
                            Text("Макс. ELO")
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

                    Toggle("Я играю в этой игре", isOn: $draft.iAmPlaying)
                    Toggle("Рейтинговая игра (влияет на ELO)", isOn: $draft.isRatingGame)
                }

                Section("Управление игрой") {
                    Toggle("Любой может приглашать игроков", isOn: $draft.anyoneCanInvite)
                    Toggle("Любой игрок может вносить результат", isOn: $draft.anyPlayerCanInputResults)
                    Toggle("Вход без подтверждения", isOn: $draft.entranceWithoutConfirmation)
                }

                Section("Дополнительные комментарии") {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 110)
                        .accessibilityLabel("Заметки")
                        .accessibilityHint("Укажите, что взять с собой и правила игры")
                }

                Section {
                    Button {
                        switch appViewModel.createGame(from: draft) {
                        case .success(let created):
                            createdMessage = "Игра создана в \(created.locationName) на \(DateFormatterService.tournamentDateTime.string(from: created.startAt))."
                            if let inviteLink = created.inviteLink {
                                createdMessage += "\nСсылка-приглашение: \(inviteLink)"
                            }
                            showCreatedAlert = true
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
                        Text("Создать игру")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("+ Новая игра")
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: draft.format) { format in
                draft.maxPlayers = format.defaultMaxPlayers
            }
            .alert("Игра создана", isPresented: $showCreatedAlert) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(createdMessage)
            }
            .alert("Не удалось создать игру", isPresented: $showErrorAlert) {
                Button("ОК", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .permissionDeniedAlert(message: $permissionMessage)
        }
    }
}
