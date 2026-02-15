import Foundation

enum MatchOutcome: String, Codable {
    case win
    case draw
    case loss
}

struct PlayerMatch: Identifiable, Equatable, Codable {
    let id: UUID
    let date: Date
    let opponent: String
    let result: String
    let score: String
    let ratingDelta: Int
    let isCompleted: Bool
    let outcome: MatchOutcome?

    init(
        id: UUID,
        date: Date,
        opponent: String,
        result: String,
        score: String,
        ratingDelta: Int,
        isCompleted: Bool = true,
        outcome: MatchOutcome? = nil
    ) {
        self.id = id
        self.date = date
        self.opponent = opponent
        self.result = result
        self.score = score
        self.ratingDelta = ratingDelta
        self.isCompleted = isCompleted
        self.outcome = outcome
    }
}
