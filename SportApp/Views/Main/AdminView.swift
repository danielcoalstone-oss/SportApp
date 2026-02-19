import SwiftUI

struct AdminView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var selectedUserId: UUID?
    @State private var suspensionReason = ""

    var body: some View {
        NavigationStack {
            if appViewModel.currentUser?.isAdmin == true {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        usersBlock
                        deletionBlock
                    }
                    .padding()
                }
                .appScreenBackground()
                .navigationTitle("Admin")
            } else {
                PermissionDeniedView()
            }
        }
        .alert("Admin Action", isPresented: adminActionBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appViewModel.adminActionMessage ?? "")
        }
        .permissionDeniedAlert(message: $appViewModel.adminActionMessage)
    }

    private var usersBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Users")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Button("Prepare Investor Demo Data") {
                appViewModel.adminPrepareInvestorDemoData()
            }
            .buttonStyle(.borderedProminent)

            Button("Seed Shared Demo Data To DB") {
                appViewModel.adminSeedSharedDemoDataToBackend()
            }
            .buttonStyle(.bordered)

            ForEach(appViewModel.users) { user in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        PlayerAvatarView(
                            name: user.fullName,
                            imageData: user.avatarImageData,
                            size: 32
                        )
                        Text(user.fullName)
                            .font(.headline)
                        Spacer()
                        RoleBadge(
                            tags: RoleTagProvider.tags(for: user, tournaments: appViewModel.visibleTournaments),
                            size: .small
                        )
                    }

                    HStack(spacing: 8) {
                        Button("Set Player") {
                            appViewModel.adminUpdateUserRole(userId: user.id, role: .player)
                        }
                        .buttonStyle(.bordered)

                        Button("Set Admin") {
                            appViewModel.adminUpdateUserRole(userId: user.id, role: .admin)
                        }
                        .buttonStyle(.bordered)

                        Button(user.isSuspended ? "Unsuspend" : "Suspend") {
                            selectedUserId = user.id
                            if user.isSuspended {
                                appViewModel.adminSetSuspended(userId: user.id, isSuspended: false, reason: nil)
                                selectedUserId = nil
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    if user.isSuspended, let reason = user.suspensionReason, !reason.isEmpty {
                        Text("Reason: \(reason)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if selectedUserId == user.id && !user.isSuspended {
                        TextField("Suspension reason", text: $suspensionReason)
                            .textFieldStyle(.roundedBorder)
                        Button("Confirm Suspend", role: .destructive) {
                            appViewModel.adminSetSuspended(
                                userId: user.id,
                                isSuspended: true,
                                reason: suspensionReason
                            )
                            suspensionReason = ""
                            selectedUserId = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .appCard()
            }
        }
    }

    private var deletionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Soft Delete")
                .font(.title3.bold())
                .foregroundStyle(.white)

            if appViewModel.visibleCreatedGames.isEmpty,
               appViewModel.visibleTournaments.isEmpty,
               appViewModel.visiblePractices.isEmpty {
                Text("No active records to delete")
                    .foregroundStyle(.secondary)
            }

            ForEach(appViewModel.visibleCreatedGames) { game in
                HStack {
                    Text("Match: \(game.locationName)")
                    Spacer()
                    Button("Delete", role: .destructive) {
                        appViewModel.adminDeleteMatch(gameId: game.id)
                    }
                    .buttonStyle(.bordered)
                }
            }

            ForEach(appViewModel.visibleTournaments) { tournament in
                HStack {
                    Text("Tournament: \(tournament.title)")
                    Spacer()
                    Button("Delete", role: .destructive) {
                        appViewModel.adminDeleteTournament(tournamentId: tournament.id)
                    }
                    .buttonStyle(.bordered)
                }
            }

            ForEach(appViewModel.visiblePractices) { session in
                HStack {
                    Text("Session: \(session.title)")
                    Spacer()
                    Button("Delete", role: .destructive) {
                        appViewModel.adminDeleteSession(sessionId: session.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var adminActionBinding: Binding<Bool> {
        Binding(
            get: { appViewModel.adminActionMessage != nil },
            set: { isPresented in
                if !isPresented {
                    appViewModel.adminActionMessage = nil
                }
            }
        )
    }
}
