import SwiftUI
import UIKit

struct RoleBadge: View {
    enum Size {
        case small
        case medium

        var font: Font {
            switch self {
            case .small:
                return .caption2.weight(.semibold)
            case .medium:
                return .caption.weight(.bold)
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            }
        }
    }

    let tags: [String]
    let size: Size

    var body: some View {
        if !tags.isEmpty {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(localizedTag(tag))
                        .font(size.font)
                        .padding(.horizontal, size.horizontalPadding)
                        .padding(.vertical, size.verticalPadding)
                        .foregroundStyle(color(for: tag).foreground)
                        .background(color(for: tag).background, in: Capsule())
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(tags.map(localizedTag).joined(separator: ", "))
        }
    }

    private func color(for tag: String) -> (background: Color, foreground: Color) {
        switch tag.uppercased() {
        case "ADMIN":
            return (.red, .white)
        case "ORGANIZER", "ORGANISER":
            return (.orange, .black)
        default:
            return (.blue, .white)
        }
    }

    private func localizedTag(_ tag: String) -> String {
        switch tag.uppercased() {
        case "ADMIN":
            return "АДМИН"
        case "ORGANIZER", "ORGANISER":
            return "ОРГАНИЗАТОР"
        default:
            return "ИГРОК"
        }
    }
}

enum RoleTagProvider {
    static func tags(for user: User) -> [String] {
        [user.globalRole == .admin ? "ADMIN" : "PLAYER"]
    }

    static func tags(for user: User, tournaments: [Tournament]) -> [String] {
        let isTournamentOrganiser = tournaments.contains { tournament in
            isOrganiser(userID: user.id, ownerId: tournament.ownerId, organiserIds: tournament.organiserIds)
        }
        return tags(for: user, isOrganiser: isTournamentOrganiser)
    }

    static func tags(for user: User, in match: Match) -> [String] {
        tags(for: user, isOrganiser: isOrganiser(userID: user.id, ownerId: match.ownerId, organiserIds: match.organiserIds))
    }

    static func tags(for user: User, in tournament: Tournament) -> [String] {
        tags(for: user, isOrganiser: isOrganiser(userID: user.id, ownerId: tournament.ownerId, organiserIds: tournament.organiserIds))
    }

    private static func tags(for user: User, isOrganiser: Bool) -> [String] {
        var values = tags(for: user)
        if isOrganiser {
            values.append("ORGANIZER")
        }
        return values
    }

    private static func isOrganiser(userID: UUID, ownerId: UUID, organiserIds: [UUID]) -> Bool {
        ownerId == userID || organiserIds.contains(userID)
    }
}

struct PlayerAvatarView: View {
    let name: String
    let imageData: Data?
    var size: CGFloat = 36

    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? "P"
        let second = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + second).uppercased()
    }

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                    Text(initials)
                        .font(.system(size: max(size * 0.38, 11), weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}
