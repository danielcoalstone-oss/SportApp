import Foundation

enum PreferredFoot: String, CaseIterable, Identifiable, Codable {
    case left = "Left"
    case right = "Right"
    case both = "Both"

    var id: String { rawValue }
}

enum FootballPosition: String, CaseIterable, Identifiable, Codable, Hashable {
    case gk = "GK"
    case cb = "CB"
    case lb = "LB"
    case rb = "RB"
    case lwb = "LWB"
    case rwb = "RWB"
    case dm = "DM"
    case cm = "CM"
    case am = "AM"
    case lm = "LM"
    case rm = "RM"
    case lw = "LW"
    case rw = "RW"
    case st = "ST"
    case cf = "CF"
    case ss = "SS"

    var id: String { rawValue }
}

enum FootballPositionGroup: String, CaseIterable, Identifiable {
    case goalkeeper = "Goalkeeper"
    case defenders = "Defenders"
    case midfielders = "Midfielders"
    case forwards = "Forwards"

    var id: String { rawValue }

    var positions: [FootballPosition] {
        switch self {
        case .goalkeeper:
            return [.gk]
        case .defenders:
            return [.cb, .lb, .rb, .lwb, .rwb]
        case .midfielders:
            return [.dm, .cm, .am, .lm, .rm]
        case .forwards:
            return [.lw, .rw, .st, .cf, .ss]
        }
    }
}

struct Player: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var avatarURL: String
    var avatarImageData: Data?
    var positions: [String]
    var preferredPositions: [FootballPosition]
    var preferredFoot: PreferredFoot
    var skillLevel: Int
    var location: String
    var createdAt: Date

    init(
        id: UUID,
        name: String,
        avatarURL: String,
        avatarImageData: Data? = nil,
        positions: [String],
        preferredPositions: [FootballPosition] = [],
        preferredFoot: PreferredFoot,
        skillLevel: Int,
        location: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.avatarImageData = avatarImageData
        self.positions = positions
        self.preferredPositions = preferredPositions
        self.preferredFoot = preferredFoot
        self.skillLevel = skillLevel
        self.location = location
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatarURL
        case avatarImageData
        case positions
        case preferredPositions
        case preferredFoot
        case skillLevel
        case location
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL) ?? ""
        avatarImageData = try container.decodeIfPresent(Data.self, forKey: .avatarImageData)
        positions = try container.decodeIfPresent([String].self, forKey: .positions) ?? []
        preferredPositions = try container.decodeIfPresent([FootballPosition].self, forKey: .preferredPositions) ?? []
        preferredFoot = try container.decode(PreferredFoot.self, forKey: .preferredFoot)
        skillLevel = try container.decode(Int.self, forKey: .skillLevel)
        location = try container.decode(String.self, forKey: .location)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    static func from(user: User) -> Player {
        let fallbackPosition = user.favoritePosition.trimmingCharacters(in: .whitespacesAndNewlines)
        let positionStrings = user.preferredPositions.isEmpty
            ? (fallbackPosition.isEmpty ? [] : [fallbackPosition])
            : user.preferredPositions.map(\.rawValue)

        return Player(
            id: user.id,
            name: user.fullName,
            avatarURL: user.avatarURL ?? "",
            avatarImageData: user.avatarImageData,
            positions: positionStrings,
            preferredPositions: user.preferredPositions,
            preferredFoot: .right,
            skillLevel: max(min((user.eloRating - 900) / 200, 10), 1),
            location: user.city,
            createdAt: Date()
        )
    }
}
