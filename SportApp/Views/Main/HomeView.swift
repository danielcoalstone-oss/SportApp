import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let user = appViewModel.currentUser {
                        Text("Hi, \(user.fullName)")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Current Elo: \(user.eloRating)", systemImage: "chart.line.uptrend.xyaxis")
                            Label("Matches: \(user.matchesPlayed)", systemImage: "figure.soccer")
                            Label("Win rate: \(Int(user.winRate * 100))%", systemImage: "trophy")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCard()
                    }

                    Text("Quick Booking (Next 24h)")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if appViewModel.thisWeekQuickBookingGames.isEmpty {
                        Text("No quick booking games in the next 24 hours.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appViewModel.thisWeekQuickBookingGames.prefix(3)) { game in
                            NavigationLink {
                                GameDetailView(game: game)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
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
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appCard()
                            }
                        }
                    }

                    if !appViewModel.currentUserUpcomingCreatedGames.isEmpty {
                        Text("Upcoming Matches")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(appViewModel.currentUserUpcomingCreatedGames.prefix(3)) { game in
                            NavigationLink {
                                GameDetailView(game: game)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
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
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appCard()
                            }
                        }
                    }

                    if !appViewModel.clubs.isEmpty {
                        Text("Clubs")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(appViewModel.clubs) { club in
                            NavigationLink {
                                ClubDetailView(club: club)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(club.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text(club.location)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(club.bookingHint)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }

                }
                .padding()
            }
            .appScreenBackground()
            .navigationTitle("Main")
        }
    }
}

private struct ClubDetailView: View {
    let club: Club
    @State private var toastMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        Text(club.name)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.green.opacity(0.95))
                            .lineLimit(2)
                        Spacer()
                        Image(systemName: "star")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Text(club.location)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.green.opacity(0.9))

                    Text(club.bookingHint)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.95))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Club features:")
                            .font(.headline)
                            .foregroundStyle(.white)
                        bullet("Modern mini-football fields")
                        bullet("Evening slots available")
                        bullet("Changing rooms and showers")
                    }

                    HStack(spacing: 14) {
                        socialIcon("paperplane.fill", color: .cyan)
                        socialIcon("network", color: .blue)
                        socialIcon("camera.fill", color: .pink)
                    }
                    .padding(.top, 2)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.19, green: 0.26, blue: 0.34), Color(red: 0.05, green: 0.16, blue: 0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )

                HStack(spacing: 0) {
                    actionButton(title: "Call", icon: "phone.fill", color: .green) {
                        toastMessage = "Phone action placeholder for now."
                    }

                    actionButton(title: "Map", icon: "map.fill", color: Color.blue.opacity(0.55)) {
                        toastMessage = "Map action placeholder for now."
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    toastMessage = "Book Club action placeholder for now."
                } label: {
                    Label("Book Club", systemImage: "calendar.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("Club")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Info", isPresented: Binding(
            get: { toastMessage != nil },
            set: { newValue in
                if !newValue { toastMessage = nil }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(toastMessage ?? "")
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(text)
                .font(.title3)
                .foregroundStyle(.white)
        }
    }

    private func socialIcon(_ systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.title3.bold())
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(color, in: RoundedRectangle(cornerRadius: 12))
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(color)
        }
        .buttonStyle(.plain)
    }
}
