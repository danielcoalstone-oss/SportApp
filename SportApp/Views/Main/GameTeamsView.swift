import SwiftUI

struct GameTeamsView: View {
    @ObservedObject var viewModel: MatchDetailsViewModel
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                teamCard(team: viewModel.match.homeTeam, otherTeamId: viewModel.match.awayTeam.id)
                teamCard(team: viewModel.match.awayTeam, otherTeamId: viewModel.match.homeTeam.id)
            }
            .padding()
        }
        .navigationTitle("Команды")
        .navigationBarTitleDisplayMode(.inline)
        .permissionDeniedAlert(message: $viewModel.toastMessage)
    }

    private func teamCard(team: Team, otherTeamId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(team.name)
                .font(.headline)

            ForEach(PositionGroup.allCases) { group in
                let groupedPlayers = viewModel.participants(teamId: team.id, group: group)
                VStack(alignment: .leading, spacing: 6) {
                    Text(group.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    if groupedPlayers.isEmpty {
                        Text("Нет игроков")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(groupedPlayers) { participant in
                            HStack {
                                PlayerAvatarView(
                                    name: participant.name,
                                    imageData: appViewModel.users.first(where: { $0.id == participant.id })?.avatarImageData,
                                    size: 24
                                )
                                Menu {
                                    Button("Переместить в \(teamName(for: otherTeamId))") {
                                        viewModel.moveParticipant(participantId: participant.id, toTeamId: otherTeamId)
                                    }
                                    Divider()
                                    ForEach(PositionGroup.allCases) { target in
                                        Button(target.rawValue) {
                                            viewModel.updateParticipantPositionGroup(participantId: participant.id, group: target)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(participant.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Text("Elo \(participant.elo)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .disabled(!viewModel.canManageParticipant(participant.id))
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func teamName(for teamId: UUID) -> String {
        if teamId == viewModel.match.homeTeam.id {
            return viewModel.match.homeTeam.name
        }
        return viewModel.match.awayTeam.name
    }
}
