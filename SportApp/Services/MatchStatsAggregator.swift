import Foundation

struct PlayerMatchStats: Equatable {
    var goals = 0
    var assists = 0
    var yellowCards = 0
    var redCards = 0
    var saves = 0
}

struct MatchSummaryRow: Identifiable, Equatable {
    let id: UUID
    let participant: Participant
    let stats: PlayerMatchStats
}

enum MatchStatsAggregator {
    static func aggregate(participants: [Participant], events: [MatchEvent]) -> [UUID: PlayerMatchStats] {
        var statsByPlayerID: [UUID: PlayerMatchStats] = [:]

        for participant in participants {
            statsByPlayerID[participant.id] = PlayerMatchStats()
        }

        for event in events {
            guard var stats = statsByPlayerID[event.playerId] else { continue }

            switch event.type {
            case .goal:
                stats.goals += 1
            case .assist:
                stats.assists += 1
            case .yellow:
                stats.yellowCards += 1
            case .red:
                stats.redCards += 1
            case .save:
                stats.saves += 1
            }

            statsByPlayerID[event.playerId] = stats
        }

        return statsByPlayerID
    }

    static func summaryRows(participants: [Participant], events: [MatchEvent]) -> [MatchSummaryRow] {
        let statsByPlayerID = aggregate(participants: participants, events: events)

        return participants.map { participant in
            MatchSummaryRow(
                id: participant.id,
                participant: participant,
                stats: statsByPlayerID[participant.id] ?? PlayerMatchStats()
            )
        }
        .sorted {
            if $0.stats.goals != $1.stats.goals { return $0.stats.goals > $1.stats.goals }
            if $0.stats.assists != $1.stats.assists { return $0.stats.assists > $1.stats.assists }
            return $0.participant.name < $1.participant.name
        }
    }
}
