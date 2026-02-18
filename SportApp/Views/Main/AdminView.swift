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
                .navigationTitle("Админ")
            } else {
                PermissionDeniedView()
            }
        }
        .alert("Действие админа", isPresented: adminActionBinding) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(appViewModel.adminActionMessage ?? "")
        }
        .permissionDeniedAlert(message: $appViewModel.adminActionMessage)
    }

    private var usersBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Пользователи")
                .font(.title3.bold())

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
                        Button("Сделать игроком") {
                            appViewModel.adminUpdateUserRole(userId: user.id, role: .player)
                        }
                        .buttonStyle(.bordered)

                        Button("Сделать админом") {
                            appViewModel.adminUpdateUserRole(userId: user.id, role: .admin)
                        }
                        .buttonStyle(.bordered)

                        Button(user.isSuspended ? "Снять блок" : "Заблокировать") {
                            selectedUserId = user.id
                            if user.isSuspended {
                                appViewModel.adminSetSuspended(userId: user.id, isSuspended: false, reason: nil)
                                selectedUserId = nil
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    if user.isSuspended, let reason = user.suspensionReason, !reason.isEmpty {
                        Text("Причина: \(reason)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if selectedUserId == user.id && !user.isSuspended {
                        TextField("Причина блокировки", text: $suspensionReason)
                            .textFieldStyle(.roundedBorder)
                        Button("Подтвердить блокировку", role: .destructive) {
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
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var deletionBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Мягкое удаление")
                .font(.title3.bold())

            if appViewModel.visibleCreatedGames.isEmpty,
               appViewModel.visibleTournaments.isEmpty,
               appViewModel.visiblePractices.isEmpty {
                Text("Нет активных записей для удаления")
                    .foregroundStyle(.secondary)
            }

            ForEach(appViewModel.visibleCreatedGames) { game in
                HStack {
                    Text("Матч: \(game.locationName)")
                    Spacer()
                    Button("Удалить", role: .destructive) {
                        appViewModel.adminDeleteMatch(gameId: game.id)
                    }
                    .buttonStyle(.bordered)
                }
            }

            ForEach(appViewModel.visibleTournaments) { tournament in
                HStack {
                    Text("Турнир: \(tournament.title)")
                    Spacer()
                    Button("Удалить", role: .destructive) {
                        appViewModel.adminDeleteTournament(tournamentId: tournament.id)
                    }
                    .buttonStyle(.bordered)
                }
            }

            ForEach(appViewModel.visiblePractices) { session in
                HStack {
                    Text("Сессия: \(session.title)")
                    Spacer()
                    Button("Удалить", role: .destructive) {
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
