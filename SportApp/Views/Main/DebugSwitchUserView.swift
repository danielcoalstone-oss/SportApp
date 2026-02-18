#if DEBUG
import SwiftUI

struct DebugSwitchUserView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(appViewModel.debugSwitchUserOptions) { option in
                Button {
                    appViewModel.debugSwitchUser(to: option.user)
                    dismiss()
                } label: {
                    HStack {
                        PlayerAvatarView(
                            name: option.user.fullName,
                            imageData: option.user.avatarImageData,
                            size: 34
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(option.user.fullName)
                                .font(.headline)
                            Text(option.user.email)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        RoleBadge(
                            tags: RoleTagProvider.tags(for: option.user, tournaments: appViewModel.visibleTournaments),
                            size: .small
                        )
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Смена пользователя")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
    }
}
#endif
