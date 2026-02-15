import SwiftUI

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

            CreateGameView()
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
                            createdMessage = "Game created at \(created.locationName) on \(DateFormatterService.tournamentDateTime.string(from: created.startAt))."
                            if let inviteLink = created.inviteLink {
                                createdMessage += "\nInvite link: \(inviteLink)"
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
                        Text("Create Game")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("+ New Game")
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: draft.format) { format in
                draft.maxPlayers = format.defaultMaxPlayers
            }
            .alert("Game Created", isPresented: $showCreatedAlert) {
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
}
