import Foundation

protocol MatchLocalStore {
    func load(matchId: UUID) -> MatchLocalState?
    func save(matchId: UUID, state: MatchLocalState)
    func delete(matchId: UUID)
}

struct MatchLocalState: Codable {
    var participants: [Participant]
    var events: [MatchEvent]
    var location: String
    var startTime: Date
    var format: String
    var notes: String
    var maxPlayers: Int
    var status: MatchStatus
    var finalHomeScore: Int?
    var finalAwayScore: Int?
    var isDeleted: Bool

    init(
        participants: [Participant],
        events: [MatchEvent],
        location: String,
        startTime: Date,
        format: String,
        notes: String,
        maxPlayers: Int,
        status: MatchStatus,
        finalHomeScore: Int?,
        finalAwayScore: Int?,
        isDeleted: Bool = false
    ) {
        self.participants = participants
        self.events = events
        self.location = location
        self.startTime = startTime
        self.format = format
        self.notes = notes
        self.maxPlayers = maxPlayers
        self.status = status
        self.finalHomeScore = finalHomeScore
        self.finalAwayScore = finalAwayScore
        self.isDeleted = isDeleted
    }

    enum CodingKeys: String, CodingKey {
        case participants
        case events
        case location
        case startTime
        case format
        case notes
        case maxPlayers
        case status
        case finalHomeScore
        case finalAwayScore
        case isDeleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        participants = try container.decode([Participant].self, forKey: .participants)
        events = try container.decode([MatchEvent].self, forKey: .events)
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        startTime = try container.decodeIfPresent(Date.self, forKey: .startTime) ?? Date()
        format = try container.decodeIfPresent(String.self, forKey: .format) ?? "5v5"
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        maxPlayers = try container.decodeIfPresent(Int.self, forKey: .maxPlayers) ?? max(participants.count, 1)
        status = try container.decodeIfPresent(MatchStatus.self, forKey: .status) ?? .scheduled
        finalHomeScore = try container.decodeIfPresent(Int.self, forKey: .finalHomeScore)
        finalAwayScore = try container.decodeIfPresent(Int.self, forKey: .finalAwayScore)
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
}

final class UserDefaultsMatchLocalStore: MatchLocalStore {
    private let defaults: UserDefaults
    private let keyPrefix = "sportapp.match.localstate."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(matchId: UUID) -> MatchLocalState? {
        guard let data = defaults.data(forKey: keyPrefix + matchId.uuidString) else {
            return nil
        }

        return try? JSONDecoder().decode(MatchLocalState.self, from: data)
    }

    func save(matchId: UUID, state: MatchLocalState) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        defaults.set(data, forKey: keyPrefix + matchId.uuidString)
    }

    func delete(matchId: UUID) {
        defaults.removeObject(forKey: keyPrefix + matchId.uuidString)
    }
}
