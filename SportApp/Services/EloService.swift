import Foundation

enum EloService {
    static func calculateNewRatings(player: Int, opponent: Int, didWin: Bool, kFactor: Int = 24) -> Int {
        let expectedScore = 1.0 / (1.0 + pow(10.0, Double(opponent - player) / 400.0))
        let actualScore = didWin ? 1.0 : 0.0
        let newRating = Double(player) + Double(kFactor) * (actualScore - expectedScore)
        return Int(newRating.rounded())
    }
}
