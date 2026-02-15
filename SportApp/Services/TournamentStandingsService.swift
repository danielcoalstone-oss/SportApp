import Foundation

struct TournamentStandingRow: Identifiable, Equatable {
    let id: UUID
    let teamId: UUID
    let teamName: String
    let played: Int
    let won: Int
    let drawn: Int
    let lost: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let goalDifference: Int
    let points: Int
}

enum TournamentStandingsService {
    static func standings(for tournament: Tournament) -> [TournamentStandingRow] {
        var statsByTeam: [UUID: (played: Int, won: Int, drawn: Int, lost: Int, gf: Int, ga: Int)] = [:]

        for team in tournament.teams {
            statsByTeam[team.id] = (0, 0, 0, 0, 0, 0)
        }

        for match in tournament.matches where match.isCompleted {
            guard
                let home = match.homeScore,
                let away = match.awayScore,
                var homeStats = statsByTeam[match.homeTeamId],
                var awayStats = statsByTeam[match.awayTeamId]
            else {
                continue
            }

            homeStats.played += 1
            awayStats.played += 1
            homeStats.gf += home
            homeStats.ga += away
            awayStats.gf += away
            awayStats.ga += home

            if home > away {
                homeStats.won += 1
                awayStats.lost += 1
            } else if home < away {
                awayStats.won += 1
                homeStats.lost += 1
            } else {
                homeStats.drawn += 1
                awayStats.drawn += 1
            }

            statsByTeam[match.homeTeamId] = homeStats
            statsByTeam[match.awayTeamId] = awayStats
        }

        let rows = tournament.teams.map { team -> TournamentStandingRow in
            let stats = statsByTeam[team.id] ?? (0, 0, 0, 0, 0, 0)
            let gd = stats.gf - stats.ga
            let points = (stats.won * 3) + stats.drawn
            return TournamentStandingRow(
                id: team.id,
                teamId: team.id,
                teamName: team.name,
                played: stats.played,
                won: stats.won,
                drawn: stats.drawn,
                lost: stats.lost,
                goalsFor: stats.gf,
                goalsAgainst: stats.ga,
                goalDifference: gd,
                points: points
            )
        }

        return rows.sorted {
            if $0.points != $1.points { return $0.points > $1.points }
            if $0.goalDifference != $1.goalDifference { return $0.goalDifference > $1.goalDifference }
            if $0.goalsFor != $1.goalsFor { return $0.goalsFor > $1.goalsFor }
            return $0.teamName < $1.teamName
        }
    }
}
