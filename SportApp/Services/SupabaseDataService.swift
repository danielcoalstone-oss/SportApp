import Foundation
import UIKit

final class SupabaseDataService {
    struct InvitedParticipantData {
        let userID: UUID
        let fullName: String
        let elo: Int
    }

    private let client: SupabaseRESTClient

    init(client: SupabaseRESTClient) {
        self.client = client
    }

    func fetchProfiles() async throws -> [User] {
        let data: Data
        do {
            data = try await client.requestPostgrest(
                pathAndQuery: "profiles?select=id,full_name,email,avatar_url,favorite_position,preferred_positions,preferred_foot,skill_level,city,elo_rating,matches_played,wins,draws,losses,global_role,coach_subscription_ends_at,is_coach_subscription_paused,organizer_subscription_ends_at,is_organizer_subscription_paused,is_suspended,suspension_reason,created_at&order=created_at.asc"
            )
        } catch {
            data = try await client.requestPostgrest(
                pathAndQuery: "profiles?select=id,full_name,email,avatar_url,favorite_position,preferred_positions,city,elo_rating,matches_played,wins,draws,losses,global_role,is_suspended,suspension_reason&order=created_at.asc"
            )
        }
        let rows = try SupabaseJSON.decoder().decode([ProfileRow].self, from: data)
        return rows.map { $0.toUser() }
    }

    func fetchClubs() async throws -> [Club] {
        let data = try await client.requestPostgrest(
            pathAndQuery: "clubs?select=id,name,location,phone_number,booking_hint,is_active&is_active=eq.true&order=created_at.asc"
        )
        let rows = try SupabaseJSON.decoder().decode([ClubRow].self, from: data)
        return rows.map { $0.toClub() }
    }

    func fetchPractices() async throws -> [PracticeSession] {
        let data: Data
        do {
            data = try await client.requestPostgrest(
                pathAndQuery: "practice_sessions?select=id,title,location,start_date,duration_minutes,number_of_players,min_elo,max_elo,is_open_join,focus_area,notes,owner_id,organiser_ids,is_draft,is_deleted,deleted_at&is_deleted=eq.false&order=start_date.asc"
            )
        } catch {
            data = try await client.requestPostgrest(
                pathAndQuery: "practice_sessions?select=id,title,location,start_date,number_of_players,min_elo,max_elo,is_open_join,is_deleted,deleted_at&is_deleted=eq.false&order=start_date.asc"
            )
        }
        let rows = try SupabaseJSON.decoder().decode([PracticeRow].self, from: data)
        return rows.map { row in
            PracticeSession(
                id: row.id,
                title: row.title,
                location: row.location,
                startDate: row.startDate,
                durationMinutes: row.durationMinutes,
                numberOfPlayers: row.numberOfPlayers,
                minElo: row.minElo,
                maxElo: row.maxElo,
                isOpenJoin: row.isOpenJoin,
                focusArea: row.focusArea,
                notes: row.notes,
                ownerId: row.ownerID,
                organiserIds: row.organiserIDs,
                isDraft: row.isDraft,
                isDeleted: row.isDeleted,
                deletedAt: row.deletedAt
            )
        }
    }

    func fetchCreatedGames(usersById: [UUID: User]) async throws -> [CreatedGame] {
        let data: Data
        do {
            data = try await client.requestPostgrest(
                pathAndQuery: "matches?select=id,owner_id,organiser_ids,club_location,start_at,duration_minutes,format,location_name,address,max_players,is_private_game,has_court_booked,min_elo,max_elo,is_rating_game,anyone_can_invite,any_player_can_input_results,entrance_without_confirmation,notes,invite_link,is_draft,is_deleted,deleted_at,status,final_home_score,final_away_score&is_deleted=eq.false&order=start_at.asc"
            )
        } catch {
            data = try await client.requestPostgrest(
                pathAndQuery: "matches?select=id,owner_id,organiser_ids,club_location,start_at,duration_minutes,format,location_name,address,max_players,is_private_game,has_court_booked,min_elo,max_elo,is_rating_game,anyone_can_invite,any_player_can_input_results,entrance_without_confirmation,notes,invite_link,is_deleted,deleted_at,status,final_home_score,final_away_score&is_deleted=eq.false&order=start_at.asc"
            )
        }
        let rows = try SupabaseJSON.decoder().decode([MatchRow].self, from: data)
        guard !rows.isEmpty else { return [] }

        let matchIDs = rows.map(\.id)
        let idsCSV = matchIDs.map { $0.uuidString }.joined(separator: ",")
        let participantData = try await client.requestPostgrest(
            pathAndQuery: "match_participants?select=match_id,user_id,name,elo,rsvp_status&match_id=in.(\(idsCSV))"
        )
        let participants = try SupabaseJSON.decoder().decode([MatchParticipantRow].self, from: participantData)
        let participantsByMatch = Dictionary(grouping: participants, by: \.matchID)

        return rows.compactMap { row in
            let players = (participantsByMatch[row.id] ?? []).map { participant -> User in
                if let user = usersById[participant.userID] {
                    return user
                }
                return User(
                    id: participant.userID,
                    fullName: participant.name,
                    email: "",
                    favoritePosition: "Midfielder",
                    city: "",
                    eloRating: participant.elo,
                    matchesPlayed: 0,
                    wins: 0,
                    globalRole: .player
                )
            }

            let clubLocation = ClubLocation(rawValue: row.clubLocation ?? "") ?? .downtownArena
            let format = MatchFormat(rawValue: row.format) ?? .fiveVFive
            return CreatedGame(
                id: row.id,
                ownerId: row.ownerID,
                organiserIds: row.organiserIDs.isEmpty ? [row.ownerID] : row.organiserIDs,
                clubLocation: clubLocation,
                startAt: row.startAt,
                durationMinutes: row.durationMinutes,
                format: format,
                locationName: row.locationName,
                address: row.address ?? "",
                maxPlayers: row.maxPlayers,
                isPrivateGame: row.isPrivateGame,
                hasCourtBooked: row.hasCourtBooked,
                minElo: row.minElo,
                maxElo: row.maxElo,
                iAmPlaying: players.contains { $0.id == row.ownerID },
                isRatingGame: row.isRatingGame,
                anyoneCanInvite: row.anyoneCanInvite,
                anyPlayerCanInputResults: row.anyPlayerCanInputResults,
                entranceWithoutConfirmation: row.entranceWithoutConfirmation,
                notes: row.notes,
                createdBy: usersById[row.ownerID]?.fullName ?? "Organiser",
                inviteLink: row.inviteLink,
                players: players,
                status: row.status,
                isDraft: row.isDraft,
                finalHomeScore: row.finalHomeScore,
                finalAwayScore: row.finalAwayScore,
                isDeleted: row.isDeleted,
                deletedAt: row.deletedAt
            )
        }
    }

    func saveProfile(_ player: Player, email: String?) async throws {
        var avatarURLToSave: String?
        if let imageData = player.avatarImageData, !imageData.isEmpty {
            let optimized = optimizedJPEGData(from: imageData) ?? imageData
            avatarURLToSave = try await uploadAvatarImage(userID: player.id, data: optimized)
        }

        let favoritePosition = player.positions.first ?? "Midfielder"
        let corePayload: [String: Any] = [
            "id": player.id.uuidString,
            "full_name": player.name,
            "favorite_position": favoritePosition,
            "preferred_positions": player.preferredPositions.map(\.rawValue),
            "city": player.location
        ]

        var extendedPayload: [String: Any] = corePayload
        extendedPayload["preferred_foot"] = player.preferredFoot.rawValue
        extendedPayload["skill_level"] = player.skillLevel
        if let avatarURLToSave {
            extendedPayload["avatar_url"] = avatarURLToSave
        }
        if let email {
            extendedPayload["email"] = email
        }

        do {
            let body = try JSONSerialization.data(withJSONObject: extendedPayload)
            _ = try await client.requestPostgrest(
                pathAndQuery: "profiles?id=eq.\(player.id.uuidString)",
                method: "PATCH",
                body: body,
                extraHeaders: ["Prefer": "return=representation"]
            )
        } catch {
            var coreWithOptional: [String: Any] = corePayload
            if let avatarURLToSave {
                coreWithOptional["avatar_url"] = avatarURLToSave
            }
            if let email {
                coreWithOptional["email"] = email
            }
            let fallbackBody = try JSONSerialization.data(withJSONObject: coreWithOptional)
            _ = try await client.requestPostgrest(
                pathAndQuery: "profiles?id=eq.\(player.id.uuidString)",
                method: "PATCH",
                body: fallbackBody,
                extraHeaders: ["Prefer": "return=representation"]
            )
        }
    }

    func fetchPlayer(id: UUID) async throws -> Player {
        let data: Data
        do {
            data = try await client.requestPostgrest(
                pathAndQuery: "profiles?select=id,full_name,email,avatar_url,favorite_position,preferred_positions,preferred_foot,skill_level,city,elo_rating,created_at&id=eq.\(id.uuidString)&limit=1"
            )
        } catch {
            data = try await client.requestPostgrest(
                pathAndQuery: "profiles?select=id,full_name,email,avatar_url,favorite_position,preferred_positions,city,elo_rating,created_at&id=eq.\(id.uuidString)&limit=1"
            )
        }
        let rows = try SupabaseJSON.decoder().decode([ProfileRow].self, from: data)
        guard let row = rows.first else {
            throw PlayerProfileRepositoryError.playerNotFound
        }

        let avatarData: Data?
        if let avatarURL = row.avatarURL, avatarURL.hasPrefix("http") {
            avatarData = await downloadAvatarData(from: avatarURL)
        } else {
            avatarData = decodeAvatarData(from: row.avatarURL)
        }

        return Player(
            id: row.id,
            name: row.fullName,
            avatarURL: row.avatarURL ?? "",
            avatarImageData: avatarData,
            positions: [row.favoritePosition],
            preferredPositions: row.preferredPositions,
            preferredFoot: row.preferredFoot,
            skillLevel: row.skillLevel,
            location: row.city,
            createdAt: row.createdAt ?? Date()
        )
    }

    func updateUserStats(
        userID: UUID,
        eloRating: Int,
        matchesPlayed: Int,
        wins: Int,
        draws: Int? = nil,
        losses: Int? = nil
    ) async throws {
        var payload: [String: Any] = [
            "elo_rating": eloRating,
            "matches_played": matchesPlayed,
            "wins": wins
        ]
        if let draws {
            payload["draws"] = draws
        }
        if let losses {
            payload["losses"] = losses
        }
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "profiles?id=eq.\(userID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func fetchMatchHistory(playerID: UUID) async throws -> [PlayerMatch] {
        let data = try await client.requestPostgrest(
            pathAndQuery: "match_participants?select=match_id,matches!inner(start_at,location_name,status,final_home_score,final_away_score,notes)&user_id=eq.\(playerID.uuidString)&order=created_at.desc&limit=40"
        )

        let rows = try SupabaseJSON.decoder().decode([ParticipantHistoryRow].self, from: data)
        return rows.map { row in
            let status = row.match.status
            let isCompleted = status == .completed
            let score: String
            if let home = row.match.finalHomeScore, let away = row.match.finalAwayScore {
                score = "\(home)-\(away)"
            } else {
                score = "TBD"
            }

            return PlayerMatch(
                id: row.matchID,
                date: row.match.startAt,
                opponent: row.match.notes.isEmpty ? row.match.locationName : row.match.notes,
                result: isCompleted ? "Completed" : "Upcoming",
                score: score,
                ratingDelta: 0,
                isCompleted: isCompleted,
                outcome: nil
            )
        }
        .sorted { $0.date > $1.date }
    }

    func createMatch(game: CreatedGame) async throws {
        let matchPayload: [String: Any] = [
            "id": game.id.uuidString,
            "owner_id": game.ownerId.uuidString,
            "organiser_ids": (game.organiserIds.isEmpty ? [game.ownerId] : game.organiserIds).map(\.uuidString),
            "club_location": game.clubLocation.rawValue,
            "start_at": Self.iso8601WithFractional.string(from: game.startAt),
            "duration_minutes": game.durationMinutes,
            "format": game.format.rawValue,
            "location_name": game.locationName,
            "address": game.address,
            "notes": game.notes,
            "max_players": game.maxPlayers,
            "is_private_game": game.isPrivateGame,
            "has_court_booked": game.hasCourtBooked,
            "is_rating_game": game.isRatingGame,
            "min_elo": game.minElo,
            "max_elo": game.maxElo,
            "anyone_can_invite": game.anyoneCanInvite,
            "any_player_can_input_results": game.anyPlayerCanInputResults,
            "entrance_without_confirmation": game.entranceWithoutConfirmation,
            "invite_link": game.inviteLink as Any,
            "is_draft": game.isDraft,
            "status": game.status.rawValue
        ]

        do {
            let matchBody = try JSONSerialization.data(withJSONObject: matchPayload)
            _ = try await client.requestPostgrest(
                pathAndQuery: "matches",
                method: "POST",
                body: matchBody,
                extraHeaders: ["Prefer": "return=representation"]
            )
        } catch {
            var fallbackPayload = matchPayload
            fallbackPayload.removeValue(forKey: "is_draft")
            let fallbackBody = try JSONSerialization.data(withJSONObject: fallbackPayload)
            _ = try await client.requestPostgrest(
                pathAndQuery: "matches",
                method: "POST",
                body: fallbackBody,
                extraHeaders: ["Prefer": "return=representation"]
            )
        }

        let homeTeamId = UUID()
        let awayTeamId = UUID()
        let teamsPayload: [[String: Any]] = [
            [
                "id": homeTeamId.uuidString,
                "match_id": game.id.uuidString,
                "name": "Home Team",
                "side": "home",
                "max_players": max(game.maxPlayers / 2, 1)
            ],
            [
                "id": awayTeamId.uuidString,
                "match_id": game.id.uuidString,
                "name": "Away Team",
                "side": "away",
                "max_players": max(game.maxPlayers / 2, 1)
            ]
        ]
        let teamsBody = try JSONSerialization.data(withJSONObject: teamsPayload)
        _ = try await client.requestPostgrest(pathAndQuery: "match_teams", method: "POST", body: teamsBody)

        let participantsPayload = game.players.enumerated().map { index, player in
            [
                "match_id": game.id.uuidString,
                "user_id": player.id.uuidString,
                "name": player.fullName,
                "elo": player.eloRating,
                "match_team_id": index % 2 == 0 ? homeTeamId.uuidString : awayTeamId.uuidString,
                "position_group": "BENCH",
                "rsvp_status": player.id == game.ownerId ? "going" : "invited"
            ]
        }

        if !participantsPayload.isEmpty {
            let participantsBody = try JSONSerialization.data(withJSONObject: participantsPayload)
            _ = try await client.requestPostgrest(pathAndQuery: "match_participants", method: "POST", body: participantsBody)
        }
    }

    func softDeleteMatch(matchID: UUID) async throws {
        let payload: [String: Any] = [
            "is_deleted": true,
            "deleted_at": Self.iso8601WithFractional.string(from: Date()),
            "status": "cancelled"
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "matches?id=eq.\(matchID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func setMatchRSVP(matchID: UUID, userID: UUID, status: RSVPStatus) async throws {
        let payload: [String: Any] = [
            "p_match_id": matchID.uuidString,
            "p_target_user_id": userID.uuidString,
            "p_desired_status": status.rawValue
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        do {
            _ = try await client.requestRPC(function: "set_match_rsvp", body: body)
        } catch let error as SupabaseClientError {
            switch error {
            case .httpError(_, let message):
                let lowercased = message.lowercased()

                if lowercased.contains("participant not found") {
                    try await ensureMatchParticipantExists(matchID: matchID, userID: userID)
                    _ = try await client.requestRPC(function: "set_match_rsvp", body: body)
                    return
                }

                if lowercased.contains("function public.set_match_rsvp")
                    || lowercased.contains("could not find the function")
                    || lowercased.contains("schema cache")
                {
                    try await setMatchRSVPDirect(matchID: matchID, userID: userID, status: status)
                    return
                }

                throw error
            default:
                throw error
            }
        } catch {
            throw error
        }
    }

    func updateMatchDetails(
        matchID: UUID,
        startAt: Date,
        location: String,
        format: String,
        maxPlayers: Int,
        notes: String
    ) async throws {
        let payload: [String: Any] = [
            "start_at": Self.iso8601WithFractional.string(from: startAt),
            "location_name": location,
            "format": format,
            "max_players": maxPlayers,
            "notes": notes
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "matches?id=eq.\(matchID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func addMatchEvent(matchID: UUID, event: MatchEvent) async throws {
        let payload: [String: Any] = [
            "id": event.id.uuidString,
            "match_id": matchID.uuidString,
            "type": event.type.rawValue,
            "minute": event.minute,
            "player_id": event.playerId.uuidString,
            "created_by_id": event.createdById.uuidString,
            "created_at": Self.iso8601WithFractional.string(from: event.createdAt)
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "match_events",
            method: "POST",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func inviteParticipant(matchID: UUID, name: String, elo: Int, toHomeTeam: Bool) async throws -> InvitedParticipantData {
        guard let profile = try await findProfileByName(name) else {
            throw SupabaseClientError.httpError(status: 400, message: "Player not found. Ask the player to register first.")
        }
        guard let teamID = try await matchTeamID(matchID: matchID, side: toHomeTeam ? "home" : "away") else {
            throw SupabaseClientError.httpError(status: 400, message: "Match teams not found.")
        }

        let payload: [String: Any] = [
            "match_id": matchID.uuidString,
            "user_id": profile.id.uuidString,
            "name": profile.fullName,
            "elo": max(elo, 0),
            "match_team_id": teamID.uuidString,
            "position_group": PositionGroup.bench.rawValue,
            "rsvp_status": RSVPStatus.invited.rawValue
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "match_participants",
            method: "POST",
            body: body,
            extraHeaders: ["Prefer": "return=representation,resolution=ignore-duplicates"]
        )

        return InvitedParticipantData(
            userID: profile.id,
            fullName: profile.fullName,
            elo: profile.eloRating
        )
    }

    func removeParticipant(matchID: UUID, userID: UUID) async throws {
        _ = try await client.requestPostgrest(
            pathAndQuery: "match_participants?match_id=eq.\(matchID.uuidString)&user_id=eq.\(userID.uuidString)",
            method: "DELETE",
            body: nil,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func moveParticipantToWaitlist(matchID: UUID, userID: UUID) async throws {
        let payload: [String: Any] = [
            "rsvp_status": RSVPStatus.waitlisted.rawValue,
            "waitlisted_at": Self.iso8601WithFractional.string(from: Date())
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "match_participants?match_id=eq.\(matchID.uuidString)&user_id=eq.\(userID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func updateParticipantTeam(matchID: UUID, userID: UUID, toHomeTeam: Bool) async throws {
        guard let teamID = try await matchTeamID(matchID: matchID, side: toHomeTeam ? "home" : "away") else {
            throw SupabaseClientError.httpError(status: 400, message: "Target team not found.")
        }
        let payload: [String: Any] = ["match_team_id": teamID.uuidString]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "match_participants?match_id=eq.\(matchID.uuidString)&user_id=eq.\(userID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func updateParticipantPositionGroup(matchID: UUID, userID: UUID, group: PositionGroup) async throws {
        let payload: [String: Any] = ["position_group": group.rawValue]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "match_participants?match_id=eq.\(matchID.uuidString)&user_id=eq.\(userID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func fetchTournaments(usersById: [UUID: User]) async throws -> [Tournament] {
        let tournamentsData: Data
        do {
            tournamentsData = try await client.requestPostgrest(
                pathAndQuery: "tournaments?select=id,title,location,start_date,end_date,visibility,status,entry_fee,max_teams,format,owner_id,organiser_ids,dispute_status,is_deleted,deleted_at&is_deleted=eq.false&order=start_date.asc"
            )
        } catch {
            tournamentsData = try await client.requestPostgrest(
                pathAndQuery: "tournaments?select=id,title,location,start_date,entry_fee,max_teams,format,owner_id,organiser_ids,dispute_status,is_deleted,deleted_at&is_deleted=eq.false&order=start_date.asc"
            )
        }
        let tournamentRows = try SupabaseJSON.decoder().decode([TournamentRow].self, from: tournamentsData)
        guard !tournamentRows.isEmpty else { return [] }

        let tournamentIDs = tournamentRows.map(\.id)
        let idsCSV = tournamentIDs.map(\.uuidString).joined(separator: ",")

        let teamsData = try await client.requestPostgrest(
            pathAndQuery: "tournament_teams?select=id,tournament_id,name,max_players&tournament_id=in.(\(idsCSV))"
        )
        let teamRows = try SupabaseJSON.decoder().decode([TournamentTeamRow].self, from: teamsData)

        let membersData: Data
        do {
            membersData = try await client.requestPostgrest(
                pathAndQuery: "tournament_team_members?select=tournament_id,team_id,user_id,position_group,sort_order,is_captain&tournament_id=in.(\(idsCSV))"
            )
        } catch {
            membersData = try await client.requestPostgrest(
                pathAndQuery: "tournament_team_members?select=tournament_id,team_id,user_id&tournament_id=in.(\(idsCSV))"
            )
        }
        let memberRows = try SupabaseJSON.decoder().decode([TournamentTeamMemberRow].self, from: membersData)
        let memberRowsByTeam = Dictionary(grouping: memberRows, by: \.teamID)

        let matchesData: Data
        do {
            matchesData = try await client.requestPostgrest(
                pathAndQuery: "tournament_matches?select=id,tournament_id,home_team_id,away_team_id,start_time,location_name,status,home_score,away_score,is_completed,matchday,match_id&tournament_id=in.(\(idsCSV))"
            )
        } catch {
            matchesData = try await client.requestPostgrest(
                pathAndQuery: "tournament_matches?select=id,tournament_id,home_team_id,away_team_id,start_time,home_score,away_score,is_completed,match_id&tournament_id=in.(\(idsCSV))"
            )
        }
        let matchRows = try SupabaseJSON.decoder().decode([TournamentMatchRow].self, from: matchesData)
        let matchRowsByTournament = Dictionary(grouping: matchRows, by: \.tournamentID)
        let teamsByTournament = Dictionary(grouping: teamRows, by: \.tournamentID)

        return tournamentRows.map { tournamentRow in
            let teamEntries: [TournamentTeam] = (teamsByTournament[tournamentRow.id] ?? []).map { row in
                TournamentTeam(
                    id: row.id,
                    tournamentId: row.tournamentID,
                    name: row.name,
                    colorHex: row.colorHex,
                    createdAt: row.createdAt
                )
            }

            let teamMembers: [TournamentTeamMember] = (teamsByTournament[tournamentRow.id] ?? []).flatMap { teamRow in
                (memberRowsByTeam[teamRow.id] ?? []).map { memberRow in
                    TournamentTeamMember(
                        teamId: memberRow.teamID,
                        playerId: memberRow.userID,
                        positionGroup: memberRow.positionGroup,
                        sortOrder: memberRow.sortOrder,
                        isCaptain: memberRow.isCaptain
                    )
                }
            }

            let teams: [Team] = (teamsByTournament[tournamentRow.id] ?? []).map { row in
                let members: [User] = (memberRowsByTeam[row.id] ?? []).map { memberRow in
                    if let existing = usersById[memberRow.userID] {
                        return existing
                    }
                    return User(
                        id: memberRow.userID,
                        fullName: "Player",
                        email: "",
                        favoritePosition: "Midfielder",
                        city: "",
                        eloRating: 1400,
                        matchesPlayed: 0,
                        wins: 0,
                        globalRole: .player
                    )
                }
                return Team(
                    id: row.id,
                    name: row.name,
                    members: members,
                    maxPlayers: row.maxPlayers
                )
            }

            let matches: [TournamentMatch] = (matchRowsByTournament[tournamentRow.id] ?? []).map { row in
                TournamentMatch(
                    id: row.id,
                    tournamentId: row.tournamentID,
                    homeTeamId: row.homeTeamID,
                    awayTeamId: row.awayTeamID,
                    startTime: row.startTime,
                    locationName: row.locationName,
                    matchday: row.matchday,
                    homeScore: row.homeScore,
                    awayScore: row.awayScore,
                    status: row.status
                )
            }

            return Tournament(
                id: tournamentRow.id,
                title: tournamentRow.title,
                location: tournamentRow.location,
                startDate: tournamentRow.startDate,
                teams: teams,
                entryFee: tournamentRow.entryFee,
                maxTeams: tournamentRow.maxTeams,
                format: tournamentRow.format,
                visibility: tournamentRow.visibility,
                status: tournamentRow.status,
                ownerId: tournamentRow.ownerID,
                organiserIds: tournamentRow.organiserIDs,
                endDate: tournamentRow.endDate,
                teamEntries: teamEntries,
                teamMembers: teamMembers,
                matches: matches,
                disputeStatus: TournamentDisputeStatus(rawValue: tournamentRow.disputeStatus) ?? .none,
                isDeleted: tournamentRow.isDeleted,
                deletedAt: tournamentRow.deletedAt
            )
        }
    }

    func updateTournamentDetails(
        tournamentID: UUID,
        title: String,
        location: String,
        startDate: Date,
        format: String,
        maxTeams: Int
    ) async throws {
        let payload: [String: Any] = [
            "title": title,
            "location": location,
            "start_date": Self.iso8601WithFractional.string(from: startDate),
            "format": format,
            "status": TournamentStatus.published.rawValue,
            "max_teams": maxTeams
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "tournaments?id=eq.\(tournamentID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func createTournament(
        title: String,
        location: String,
        startDate: Date,
        endDate: Date? = nil,
        visibility: TournamentVisibility = .public,
        status: TournamentStatus = .published,
        entryFee: Double,
        maxTeams: Int,
        format: String,
        ownerID: UUID,
        organiserIDs: [UUID]
    ) async throws -> Tournament {
        let tournamentID = UUID()
        let payload: [String: Any] = [
            "id": tournamentID.uuidString,
            "title": title,
            "location": location,
            "start_date": Self.iso8601WithFractional.string(from: startDate),
            "end_date": endDate.map { Self.iso8601WithFractional.string(from: $0) } as Any,
            "visibility": visibility.rawValue,
            "status": status.rawValue,
            "entry_fee": entryFee,
            "max_teams": maxTeams,
            "format": format,
            "owner_id": ownerID.uuidString,
            "organiser_ids": Array(Set(organiserIDs + [ownerID])).map(\.uuidString),
            "dispute_status": TournamentDisputeStatus.none.rawValue,
            "is_deleted": false
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        do {
            _ = try await client.requestPostgrest(
                pathAndQuery: "tournaments",
                method: "POST",
                body: body,
                extraHeaders: ["Prefer": "return=representation"]
            )
        } catch {
            let fallbackPayload: [String: Any] = [
                "id": tournamentID.uuidString,
                "title": title,
                "location": location,
                "start_date": Self.iso8601WithFractional.string(from: startDate),
                "entry_fee": entryFee,
                "max_teams": maxTeams,
                "format": format,
                "owner_id": ownerID.uuidString,
                "organiser_ids": Array(Set(organiserIDs + [ownerID])).map(\.uuidString),
                "dispute_status": TournamentDisputeStatus.none.rawValue,
                "is_deleted": false
            ]
            let fallbackBody = try JSONSerialization.data(withJSONObject: fallbackPayload)
            _ = try await client.requestPostgrest(
                pathAndQuery: "tournaments",
                method: "POST",
                body: fallbackBody,
                extraHeaders: ["Prefer": "return=representation"]
            )
        }

        return Tournament(
            id: tournamentID,
            title: title,
            location: location,
            startDate: startDate,
            teams: [],
            entryFee: entryFee,
            maxTeams: maxTeams,
            format: format,
            visibility: visibility,
            status: status,
            ownerId: ownerID,
            organiserIds: organiserIDs,
            endDate: endDate,
            teamEntries: [],
            teamMembers: [],
            matches: [],
            disputeStatus: .none,
            isDeleted: false,
            deletedAt: nil
        )
    }

    func seedExampleTournament(for owner: User, users: [User]) async throws {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now
        let tournament = try await createTournament(
            title: "City League Showcase",
            location: owner.city.isEmpty ? "City Arena" : owner.city,
            startDate: startDate,
            entryFee: 20,
            maxTeams: 8,
            format: MatchFormat.fiveVFive.rawValue,
            ownerID: owner.id,
            organiserIDs: [owner.id]
        )

        let orderedUsers = [owner] + users.filter { $0.id != owner.id }
        let roster = Array(orderedUsers.prefix(4))
        guard !roster.isEmpty else { return }

        var createdTeams: [Team] = []
        for (index, player) in roster.enumerated() {
            let team = Team(
                id: UUID(),
                name: "Team \(index + 1)",
                members: [],
                maxPlayers: 6
            )
            try await createTournamentTeam(tournamentID: tournament.id, team: team)
            try await addTournamentTeamMember(tournamentID: tournament.id, teamID: team.id, userID: player.id)
            createdTeams.append(team)
        }

        if createdTeams.count >= 2 {
            _ = try await createTournamentMatch(
                tournamentID: tournament.id,
                ownerID: tournament.ownerId,
                organiserIDs: tournament.organiserIds,
                homeTeamID: createdTeams[0].id,
                awayTeamID: createdTeams[1].id,
                startTime: Calendar.current.date(byAdding: .hour, value: 4, to: startDate) ?? startDate,
                locationName: tournament.location,
                format: tournament.format
            )
        }
    }

    func createTournamentTeam(tournamentID: UUID, team: Team) async throws {
        let teamPayload: [String: Any] = [
            "id": team.id.uuidString,
            "tournament_id": tournamentID.uuidString,
            "name": team.name,
            "color_hex": "#2D6CC4",
            "max_players": team.maxPlayers
        ]
        let teamBody = try JSONSerialization.data(withJSONObject: teamPayload)
        do {
            _ = try await client.requestPostgrest(
                pathAndQuery: "tournament_teams",
                method: "POST",
                body: teamBody,
                extraHeaders: ["Prefer": "return=representation"]
            )
        } catch {
            let fallbackPayload: [String: Any] = [
                "id": team.id.uuidString,
                "tournament_id": tournamentID.uuidString,
                "name": team.name,
                "max_players": team.maxPlayers
            ]
            let fallbackBody = try JSONSerialization.data(withJSONObject: fallbackPayload)
            _ = try await client.requestPostgrest(
                pathAndQuery: "tournament_teams",
                method: "POST",
                body: fallbackBody,
                extraHeaders: ["Prefer": "return=representation"]
            )
        }
    }

    func deleteTournamentTeam(teamID: UUID) async throws {
        _ = try await client.requestPostgrest(
            pathAndQuery: "tournament_teams?id=eq.\(teamID.uuidString)",
            method: "DELETE",
            body: nil,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func addTournamentTeamMember(
        tournamentID: UUID,
        teamID: UUID,
        userID: UUID,
        positionGroup: PositionGroup = .bench,
        sortOrder: Int = 0,
        isCaptain: Bool = false
    ) async throws {
        let payload: [String: Any] = [
            "tournament_id": tournamentID.uuidString,
            "team_id": teamID.uuidString,
            "user_id": userID.uuidString,
            "position_group": positionGroup.rawValue,
            "sort_order": sortOrder,
            "is_captain": isCaptain
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        do {
            _ = try await client.requestPostgrest(
                pathAndQuery: "tournament_team_members",
                method: "POST",
                body: body,
                extraHeaders: ["Prefer": "return=representation"]
            )
        } catch {
            let fallbackPayload: [String: Any] = [
                "tournament_id": tournamentID.uuidString,
                "team_id": teamID.uuidString,
                "user_id": userID.uuidString
            ]
            let fallbackBody = try JSONSerialization.data(withJSONObject: fallbackPayload)
            _ = try await client.requestPostgrest(
                pathAndQuery: "tournament_team_members",
                method: "POST",
                body: fallbackBody,
                extraHeaders: ["Prefer": "return=representation"]
            )
        }
    }

    func removeTournamentTeamMember(tournamentID: UUID, teamID: UUID, userID: UUID) async throws {
        _ = try await client.requestPostgrest(
            pathAndQuery: "tournament_team_members?tournament_id=eq.\(tournamentID.uuidString)&team_id=eq.\(teamID.uuidString)&user_id=eq.\(userID.uuidString)",
            method: "DELETE",
            body: nil,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func updateTournamentTeamMember(
        tournamentID: UUID,
        teamID: UUID,
        userID: UUID,
        positionGroup: PositionGroup?,
        sortOrder: Int?,
        isCaptain: Bool?
    ) async throws {
        var payload: [String: Any] = [:]
        if let positionGroup {
            payload["position_group"] = positionGroup.rawValue
        }
        if let sortOrder {
            payload["sort_order"] = sortOrder
        }
        if let isCaptain {
            payload["is_captain"] = isCaptain
        }
        guard !payload.isEmpty else { return }

        let body = try JSONSerialization.data(withJSONObject: payload)
        do {
            _ = try await client.requestPostgrest(
                pathAndQuery: "tournament_team_members?tournament_id=eq.\(tournamentID.uuidString)&team_id=eq.\(teamID.uuidString)&user_id=eq.\(userID.uuidString)",
                method: "PATCH",
                body: body,
                extraHeaders: ["Prefer": "return=representation"]
            )
        } catch {
            // Backward-compatible fallback for schemas without new columns.
            if payload.keys.contains("position_group") || payload.keys.contains("sort_order") || payload.keys.contains("is_captain") {
                return
            }
            throw error
        }
    }

    func createTournamentMatch(
        tournamentID: UUID,
        ownerID: UUID,
        organiserIDs: [UUID],
        homeTeamID: UUID,
        awayTeamID: UUID,
        startTime: Date,
        locationName: String,
        format: String,
        matchday: Int? = nil
    ) async throws -> TournamentMatch {
        let matchID = UUID()
        let maxPlayers = format == MatchFormat.elevenVEleven.rawValue ? 22 : (format == MatchFormat.sevenVSeven.rawValue ? 14 : 10)
        let matchPayload: [String: Any] = [
            "id": matchID.uuidString,
            "owner_id": ownerID.uuidString,
            "organiser_ids": organiserIDs.map(\.uuidString),
            "start_at": Self.iso8601WithFractional.string(from: startTime),
            "duration_minutes": 90,
            "format": format,
            "location_name": locationName,
            "address": "",
            "notes": "Tournament match",
            "max_players": maxPlayers,
            "is_private_game": false,
            "has_court_booked": false,
            "is_rating_game": true,
            "min_elo": 800,
            "max_elo": 3000,
            "anyone_can_invite": false,
            "any_player_can_input_results": false,
            "entrance_without_confirmation": false,
            "status": "scheduled"
        ]
        let matchBody = try JSONSerialization.data(withJSONObject: matchPayload)
        _ = try await client.requestPostgrest(pathAndQuery: "matches", method: "POST", body: matchBody)

        let homeMatchTeamID = UUID()
        let awayMatchTeamID = UUID()
        let teamsPayload: [[String: Any]] = [
            [
                "id": homeMatchTeamID.uuidString,
                "match_id": matchID.uuidString,
                "name": "Home Team",
                "side": "home",
                "max_players": max(maxPlayers / 2, 1)
            ],
            [
                "id": awayMatchTeamID.uuidString,
                "match_id": matchID.uuidString,
                "name": "Away Team",
                "side": "away",
                "max_players": max(maxPlayers / 2, 1)
            ]
        ]
        let teamsBody = try JSONSerialization.data(withJSONObject: teamsPayload)
        _ = try await client.requestPostgrest(pathAndQuery: "match_teams", method: "POST", body: teamsBody)

        let homeMemberIDs = try await fetchTournamentTeamMemberIDs(teamID: homeTeamID)
        let awayMemberIDs = try await fetchTournamentTeamMemberIDs(teamID: awayTeamID)
        let allMemberIDs = Array(Set(homeMemberIDs + awayMemberIDs))
        let profilesByID = try await fetchProfilesByIDs(allMemberIDs)

        let participantPayload: [[String: Any]] = (homeMemberIDs + awayMemberIDs).compactMap { memberID in
            guard let profile = profilesByID[memberID] else { return nil }
            let onHome = homeMemberIDs.contains(memberID)
            return [
                "match_id": matchID.uuidString,
                "user_id": memberID.uuidString,
                "name": profile.fullName,
                "elo": profile.eloRating,
                "match_team_id": onHome ? homeMatchTeamID.uuidString : awayMatchTeamID.uuidString,
                "position_group": PositionGroup.bench.rawValue,
                "rsvp_status": RSVPStatus.going.rawValue
            ]
        }

        if !participantPayload.isEmpty {
            let participantsBody = try JSONSerialization.data(withJSONObject: participantPayload)
            _ = try await client.requestPostgrest(pathAndQuery: "match_participants", method: "POST", body: participantsBody)
        }

        let tournamentMatchPayload: [String: Any] = [
            "id": matchID.uuidString,
            "tournament_id": tournamentID.uuidString,
            "home_team_id": homeTeamID.uuidString,
            "away_team_id": awayTeamID.uuidString,
            "start_time": Self.iso8601WithFractional.string(from: startTime),
            "location_name": locationName,
            "status": TournamentMatchStatus.scheduled.rawValue,
            "is_completed": false,
            "matchday": matchday as Any,
            "match_id": matchID.uuidString
        ]
        let tournamentMatchBody = try JSONSerialization.data(withJSONObject: tournamentMatchPayload)
        do {
            _ = try await client.requestPostgrest(pathAndQuery: "tournament_matches", method: "POST", body: tournamentMatchBody)
        } catch {
            let fallbackPayload: [String: Any] = [
                "id": matchID.uuidString,
                "tournament_id": tournamentID.uuidString,
                "home_team_id": homeTeamID.uuidString,
                "away_team_id": awayTeamID.uuidString,
                "start_time": Self.iso8601WithFractional.string(from: startTime),
                "is_completed": false,
                "match_id": matchID.uuidString
            ]
            let fallbackBody = try JSONSerialization.data(withJSONObject: fallbackPayload)
            _ = try await client.requestPostgrest(pathAndQuery: "tournament_matches", method: "POST", body: fallbackBody)
        }

        return TournamentMatch(
            id: matchID,
            tournamentId: tournamentID,
            homeTeamId: homeTeamID,
            awayTeamId: awayTeamID,
            startTime: startTime,
            locationName: locationName,
            matchday: matchday,
            status: .scheduled
        )
    }

    func updateTournamentMatchResult(
        matchID: UUID,
        homeScore: Int,
        awayScore: Int,
        reason: String? = nil
    ) async throws {
        let lookupData = try await client.requestPostgrest(
            pathAndQuery: "tournament_matches?select=match_id&id=eq.\(matchID.uuidString)&limit=1"
        )
        let lookupRows = try SupabaseJSON.decoder().decode([TournamentMatchLookupRow].self, from: lookupData)
        let linkedMatchID = lookupRows.first?.matchID

        let tournamentMatchPayload: [String: Any] = [
            "home_score": homeScore,
            "away_score": awayScore,
            "status": TournamentMatchStatus.completed.rawValue,
            "is_completed": true
        ]
        let tournamentBody = try JSONSerialization.data(withJSONObject: tournamentMatchPayload)
        do {
            _ = try await client.requestPostgrest(
                pathAndQuery: "tournament_matches?id=eq.\(matchID.uuidString)",
                method: "PATCH",
                body: tournamentBody,
                extraHeaders: ["Prefer": "return=representation"]
            )
        } catch {
            let fallbackPayload: [String: Any] = [
                "home_score": homeScore,
                "away_score": awayScore,
                "is_completed": true
            ]
            let fallbackBody = try JSONSerialization.data(withJSONObject: fallbackPayload)
            _ = try await client.requestPostgrest(
                pathAndQuery: "tournament_matches?id=eq.\(matchID.uuidString)",
                method: "PATCH",
                body: fallbackBody,
                extraHeaders: ["Prefer": "return=representation"]
            )
        }

        if let linkedMatchID {
            try await completeMatchAndApplyElo(matchID: linkedMatchID, homeScore: homeScore, awayScore: awayScore)
        }
    }

    func updateTournamentDispute(tournamentID: UUID, status: TournamentDisputeStatus) async throws {
        let payload = ["dispute_status": status.rawValue]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "tournaments?id=eq.\(tournamentID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func updateUserRole(userID: UUID, role: GlobalRole) async throws {
        let payload: [String: Any] = ["global_role": role.rawValue]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "profiles?id=eq.\(userID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func setUserSuspended(userID: UUID, isSuspended: Bool, reason: String?) async throws {
        let payload: [String: Any] = [
            "is_suspended": isSuspended,
            "suspension_reason": isSuspended ? (reason ?? "") : NSNull()
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "profiles?id=eq.\(userID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func setOrganizerSubscription(userID: UUID, endsAt: Date?, isPaused: Bool) async throws {
        let payload: [String: Any] = [
            "organizer_subscription_ends_at": endsAt.map { Self.iso8601WithFractional.string(from: $0) } as Any,
            "is_organizer_subscription_paused": isPaused
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "profiles?id=eq.\(userID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func softDeleteTournament(tournamentID: UUID) async throws {
        let payload: [String: Any] = [
            "is_deleted": true,
            "deleted_at": Self.iso8601WithFractional.string(from: Date())
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "tournaments?id=eq.\(tournamentID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func softDeletePractice(sessionID: UUID) async throws {
        let payload: [String: Any] = [
            "is_deleted": true,
            "deleted_at": Self.iso8601WithFractional.string(from: Date())
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "practice_sessions?id=eq.\(sessionID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    func createPractice(session: PracticeSession) async throws -> PracticeSession {
        let payload: [String: Any] = [
            "id": session.id.uuidString,
            "title": session.title,
            "location": session.location,
            "start_date": Self.iso8601WithFractional.string(from: session.startDate),
            "duration_minutes": session.durationMinutes,
            "number_of_players": session.numberOfPlayers,
            "min_elo": session.minElo,
            "max_elo": session.maxElo,
            "is_open_join": session.isOpenJoin,
            "focus_area": session.focusArea,
            "notes": session.notes,
            "owner_id": session.ownerId?.uuidString as Any,
            "organiser_ids": session.organiserIds.map(\.uuidString),
            "is_draft": session.isDraft,
            "is_deleted": false
        ]
        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            _ = try await client.requestPostgrest(
                pathAndQuery: "practice_sessions",
                method: "POST",
                body: body,
                extraHeaders: ["Prefer": "return=representation"]
            )
            return session
        } catch {
            let fallbackPayload: [String: Any] = [
                "id": session.id.uuidString,
                "title": session.title,
                "location": session.location,
                "start_date": Self.iso8601WithFractional.string(from: session.startDate),
                "number_of_players": session.numberOfPlayers,
                "min_elo": session.minElo,
                "max_elo": session.maxElo,
                "is_open_join": session.isOpenJoin,
                "is_deleted": false
            ]
            let fallbackBody = try JSONSerialization.data(withJSONObject: fallbackPayload)
            _ = try await client.requestPostgrest(
                pathAndQuery: "practice_sessions",
                method: "POST",
                body: fallbackBody,
                extraHeaders: ["Prefer": "return=representation"]
            )
            return session
        }
    }

    func updatePractice(session: PracticeSession) async throws {
        let payload: [String: Any] = [
            "title": session.title,
            "location": session.location,
            "start_date": Self.iso8601WithFractional.string(from: session.startDate),
            "duration_minutes": session.durationMinutes,
            "number_of_players": session.numberOfPlayers,
            "min_elo": session.minElo,
            "max_elo": session.maxElo,
            "is_open_join": session.isOpenJoin,
            "focus_area": session.focusArea,
            "notes": session.notes,
            "is_draft": session.isDraft
        ]
        do {
            let body = try JSONSerialization.data(withJSONObject: payload)
            _ = try await client.requestPostgrest(
                pathAndQuery: "practice_sessions?id=eq.\(session.id.uuidString)",
                method: "PATCH",
                body: body,
                extraHeaders: ["Prefer": "return=representation"]
            )
        } catch {
            let fallbackPayload: [String: Any] = [
                "title": session.title,
                "location": session.location,
                "start_date": Self.iso8601WithFractional.string(from: session.startDate),
                "number_of_players": session.numberOfPlayers,
                "min_elo": session.minElo,
                "max_elo": session.maxElo,
                "is_open_join": session.isOpenJoin
            ]
            let fallbackBody = try JSONSerialization.data(withJSONObject: fallbackPayload)
            _ = try await client.requestPostgrest(
                pathAndQuery: "practice_sessions?id=eq.\(session.id.uuidString)",
                method: "PATCH",
                body: fallbackBody,
                extraHeaders: ["Prefer": "return=representation"]
            )
        }
    }

    func fetchCoachReviews() async throws -> [CoachReview] {
        do {
            let data = try await client.requestPostgrest(
                pathAndQuery: "coach_reviews?select=id,coach_id,author_id,author_name,rating,text,created_at&order=created_at.desc"
            )
            let rows = try SupabaseJSON.decoder().decode([CoachReviewRow].self, from: data)
            return rows.map { $0.toReview() }
        } catch {
            let data = try await client.requestPostgrest(
                pathAndQuery: "coach_reviews?select=id,coach_id,author_id,rating,text,created_at&order=created_at.desc"
            )
            let rows = try SupabaseJSON.decoder().decode([CoachReviewFallbackRow].self, from: data)
            let authorNamesByID = try await fetchProfileNamesByIDs(Array(Set(rows.map(\.authorID))))
            return rows.map { row in
                CoachReview(
                    id: row.id,
                    coachID: row.coachID,
                    authorID: row.authorID,
                    authorName: authorNamesByID[row.authorID] ?? "Player",
                    rating: row.rating,
                    text: row.text,
                    createdAt: row.createdAt
                )
            }
        }
    }

    func addCoachReview(_ review: CoachReview) async throws {
        let upsertPayloadWithAuthorName: [String: Any] = [
            "coach_id": review.coachID.uuidString,
            "author_id": review.authorID.uuidString,
            "author_name": review.authorName,
            "rating": review.rating,
            "text": review.text
        ]
        let upsertPayloadFallback: [String: Any] = [
            "coach_id": review.coachID.uuidString,
            "author_id": review.authorID.uuidString,
            "rating": review.rating,
            "text": review.text
        ]

        do {
            let body = try JSONSerialization.data(withJSONObject: upsertPayloadWithAuthorName)
            _ = try await client.requestPostgrest(
                pathAndQuery: "coach_reviews?on_conflict=author_id,coach_id",
                method: "POST",
                body: body,
                extraHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
            )
        } catch {
            let body = try JSONSerialization.data(withJSONObject: upsertPayloadFallback)
            _ = try await client.requestPostgrest(
                pathAndQuery: "coach_reviews?on_conflict=author_id,coach_id",
                method: "POST",
                body: body,
                extraHeaders: ["Prefer": "resolution=merge-duplicates,return=representation"]
            )
        }
    }

    func completeMatchAndApplyElo(matchID: UUID, homeScore: Int, awayScore: Int) async throws {
        let payload: [String: Any] = [
            "p_match_id": matchID.uuidString,
            "p_home_score": homeScore,
            "p_away_score": awayScore
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)

        do {
            _ = try await client.requestRPC(function: "complete_match_and_apply_elo", body: body)
            return
        } catch {
            // Fallback 1: complete score + stats without Elo.
            do {
                _ = try await client.requestRPC(function: "complete_or_update_match_score", body: body)
                return
            } catch {
                // Fallback 2: ensure match is at least completed in DB.
                let fallbackPayload: [String: Any] = [
                    "status": MatchStatus.completed.rawValue,
                    "final_home_score": homeScore,
                    "final_away_score": awayScore
                ]
                let fallbackBody = try JSONSerialization.data(withJSONObject: fallbackPayload)
                _ = try await client.requestPostgrest(
                    pathAndQuery: "matches?id=eq.\(matchID.uuidString)",
                    method: "PATCH",
                    body: fallbackBody,
                    extraHeaders: ["Prefer": "return=representation"]
                )
                throw SupabaseClientError.httpError(
                    status: 500,
                    message: "Match completed without stats update. Run SQL function updates in Supabase."
                )
            }
        }
    }

    func fetchMatchDetails(matchID: UUID) async throws -> Match? {
        let matchData = try await client.requestPostgrest(
            pathAndQuery: "matches?select=id,owner_id,organiser_ids,location_name,start_at,format,notes,max_players,is_rating_game,has_court_booked,status,final_home_score,final_away_score,is_deleted&id=eq.\(matchID.uuidString)&limit=1"
        )
        let matches = try SupabaseJSON.decoder().decode([MatchDetailsRow].self, from: matchData)
        guard let row = matches.first, !row.isDeleted else { return nil }

        let teamsData = try await client.requestPostgrest(
            pathAndQuery: "match_teams?select=id,name,side,max_players&match_id=eq.\(matchID.uuidString)"
        )
        let teamRows = try SupabaseJSON.decoder().decode([MatchTeamRow].self, from: teamsData)
        guard
            let homeRow = teamRows.first(where: { $0.side == "home" }),
            let awayRow = teamRows.first(where: { $0.side == "away" })
        else {
            return nil
        }

        let participantsData = try await client.requestPostgrest(
            pathAndQuery: "match_participants?select=user_id,name,match_team_id,elo,position_group,rsvp_status,invited_at,waitlisted_at&match_id=eq.\(matchID.uuidString)"
        )
        let participantRows = try SupabaseJSON.decoder().decode([MatchParticipantDetailsRow].self, from: participantsData)
        let participantIDs = participantRows.map(\.userID)
        let usersByID = try await fetchProfilesByIDs(participantIDs)

        let participants: [Participant] = participantRows.map { row in
            Participant(
                id: row.userID,
                name: row.name,
                teamId: row.matchTeamID,
                elo: row.elo,
                positionGroup: row.positionGroup,
                rsvpStatus: row.rsvpStatus,
                invitedAt: row.invitedAt,
                waitlistedAt: row.waitlistedAt
            )
        }

        let homeMembers = participants.compactMap { participant in
            participant.teamId == homeRow.id ? usersByID[participant.id] : nil
        }
        let awayMembers = participants.compactMap { participant in
            participant.teamId == awayRow.id ? usersByID[participant.id] : nil
        }

        let eventsData = try await client.requestPostgrest(
            pathAndQuery: "match_events?select=id,type,minute,player_id,created_by_id,created_at&match_id=eq.\(matchID.uuidString)&order=minute.asc"
        )
        let eventRows = try SupabaseJSON.decoder().decode([MatchEventRow].self, from: eventsData)
        let events = eventRows.map {
            MatchEvent(
                id: $0.id,
                type: $0.type,
                minute: $0.minute,
                playerId: $0.playerID,
                createdById: $0.createdByID,
                createdAt: $0.createdAt
            )
        }

        let homeTeam = Team(id: homeRow.id, name: homeRow.name, members: homeMembers, maxPlayers: homeRow.maxPlayers)
        let awayTeam = Team(id: awayRow.id, name: awayRow.name, members: awayMembers, maxPlayers: awayRow.maxPlayers)

        return Match(
            id: row.id,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            participants: participants,
            events: events,
            location: row.locationName,
            startTime: row.startAt,
            format: row.format,
            notes: row.notes,
            isRatingGame: row.isRatingGame,
            isFieldBooked: row.hasCourtBooked,
            maxPlayers: row.maxPlayers,
            status: row.status,
            finalHomeScore: row.finalHomeScore,
            finalAwayScore: row.finalAwayScore,
            ownerId: row.ownerID,
            organiserIds: row.organiserIDs
        )
    }

    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func uploadAvatarImage(userID: UUID, data: Data) async throws -> String {
        let objectPath = "\(userID.uuidString.lowercased())/avatar-\(UUID().uuidString.lowercased()).jpg"
        let escapedObjectPath = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? objectPath

        _ = try await client.requestStorage(
            path: "object/avatars/\(escapedObjectPath)",
            method: "POST",
            body: data,
            contentType: "image/jpeg",
            extraHeaders: ["x-upsert": "true"]
        )

        return "\(client.baseURL.absoluteString)/storage/v1/object/public/avatars/\(objectPath)"
    }

    private func downloadAvatarData(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return data
        } catch {
            return nil
        }
    }

    private func optimizedJPEGData(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 768
        let resized = resizedImage(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: 0.75)
    }

    private func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxCurrent = max(size.width, size.height)
        guard maxCurrent > maxDimension, maxCurrent > 0 else {
            return image
        }

        let scale = maxDimension / maxCurrent
        let newSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func decodeAvatarData(from raw: String?) -> Data? {
        guard let raw, !raw.isEmpty else { return nil }
        guard !raw.hasPrefix("http") else { return nil }
        let base64: String
        if let commaIndex = raw.firstIndex(of: ",") {
            base64 = String(raw[raw.index(after: commaIndex)...])
        } else {
            base64 = raw
        }
        return Data(base64Encoded: base64)
    }

    private func matchTeamID(matchID: UUID, side: String) async throws -> UUID? {
        let encodedSide = side.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? side
        let data = try await client.requestPostgrest(
            pathAndQuery: "match_teams?select=id&match_id=eq.\(matchID.uuidString)&side=eq.\(encodedSide)&limit=1"
        )
        let rows = try SupabaseJSON.decoder().decode([IDOnlyRow].self, from: data)
        return rows.first?.id
    }

    private func findProfileByName(_ name: String) async throws -> ProfileLookupRow? {
        let encodedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let data = try await client.requestPostgrest(
            pathAndQuery: "profiles?select=id,full_name,elo_rating&full_name=eq.\(encodedName)&limit=1"
        )
        let rows = try SupabaseJSON.decoder().decode([ProfileLookupRow].self, from: data)
        return rows.first
    }

    private func fetchTournamentTeamMemberIDs(teamID: UUID) async throws -> [UUID] {
        let data = try await client.requestPostgrest(
            pathAndQuery: "tournament_team_members?select=user_id&team_id=eq.\(teamID.uuidString)"
        )
        let rows = try SupabaseJSON.decoder().decode([TournamentTeamMemberUserRow].self, from: data)
        return rows.map(\.userID)
    }

    private func fetchProfilesByIDs(_ ids: [UUID]) async throws -> [UUID: User] {
        guard !ids.isEmpty else { return [:] }
        let csv = ids.map(\.uuidString).joined(separator: ",")
        let data = try await client.requestPostgrest(
            pathAndQuery: "profiles?select=id,full_name,email,avatar_url,favorite_position,preferred_positions,city,elo_rating,matches_played,wins,draws,losses,global_role,coach_subscription_ends_at,is_coach_subscription_paused,organizer_subscription_ends_at,is_organizer_subscription_paused,is_suspended,suspension_reason&id=in.(\(csv))"
        )
        let rows = try SupabaseJSON.decoder().decode([ProfileRow].self, from: data)
        let hydratedUsers = await hydrateUsers(from: rows)
        return Dictionary(
            hydratedUsers.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func fetchProfileNamesByIDs(_ ids: [UUID]) async throws -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }
        let csv = ids.map(\.uuidString).joined(separator: ",")
        let data = try await client.requestPostgrest(
            pathAndQuery: "profiles?select=id,full_name&id=in.(\(csv))"
        )
        let rows = try SupabaseJSON.decoder().decode([ProfileNameRow].self, from: data)
        return Dictionary(rows.map { ($0.id, $0.fullName) }, uniquingKeysWith: { first, _ in first })
    }

    private func hydrateUsers(from rows: [ProfileRow]) async -> [User] {
        await withTaskGroup(of: (UUID, User).self) { group in
            for row in rows {
                group.addTask {
                    let avatarData: Data?
                    if let avatarURL = row.avatarURL, avatarURL.hasPrefix("http") {
                        avatarData = await self.downloadAvatarData(from: avatarURL)
                    } else {
                        avatarData = row.decodeAvatarData()
                    }
                    return (row.id, row.toUser(avatarImageData: avatarData))
                }
            }

            var orderedUsersByID: [UUID: User] = [:]
            orderedUsersByID.reserveCapacity(rows.count)
            for await (id, user) in group {
                orderedUsersByID[id] = user
            }

            return rows.compactMap { orderedUsersByID[$0.id] }
        }
    }

    private func ensureMatchParticipantExists(matchID: UUID, userID: UUID) async throws {
        let existing = try await client.requestPostgrest(
            pathAndQuery: "match_participants?select=id&match_id=eq.\(matchID.uuidString)&user_id=eq.\(userID.uuidString)&limit=1"
        )
        let existingRows = try SupabaseJSON.decoder().decode([IDOnlyRow].self, from: existing)
        if !existingRows.isEmpty {
            return
        }

        guard let user = try await fetchProfilesByIDs([userID])[userID] else {
            throw SupabaseClientError.httpError(status: 400, message: "Profile not found for RSVP user.")
        }

        let homeTeamID = try await matchTeamID(matchID: matchID, side: "home")
        let awayTeamID = try await matchTeamID(matchID: matchID, side: "away")
        guard let teamID = homeTeamID ?? awayTeamID else {
            throw SupabaseClientError.httpError(status: 400, message: "No match teams found.")
        }

        let payload: [String: Any] = [
            "match_id": matchID.uuidString,
            "user_id": userID.uuidString,
            "name": user.fullName,
            "elo": user.eloRating,
            "match_team_id": teamID.uuidString,
            "position_group": PositionGroup.bench.rawValue,
            "rsvp_status": RSVPStatus.invited.rawValue
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "match_participants",
            method: "POST",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }

    private func setMatchRSVPDirect(matchID: UUID, userID: UUID, status: RSVPStatus) async throws {
        try await ensureMatchParticipantExists(matchID: matchID, userID: userID)

        let payload: [String: Any] = [
            "rsvp_status": status.rawValue,
            "waitlisted_at": status == .waitlisted
                ? Self.iso8601WithFractional.string(from: Date())
                : NSNull()
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await client.requestPostgrest(
            pathAndQuery: "match_participants?match_id=eq.\(matchID.uuidString)&user_id=eq.\(userID.uuidString)",
            method: "PATCH",
            body: body,
            extraHeaders: ["Prefer": "return=representation"]
        )
    }
}

private struct ProfileRow: Decodable {
    let id: UUID
    let fullName: String
    let email: String
    let avatarURL: String?
    let favoritePosition: String
    let preferredPositions: [FootballPosition]
    let preferredFoot: PreferredFoot
    let skillLevel: Int
    let city: String
    let eloRating: Int
    let matchesPlayed: Int
    let wins: Int
    let draws: Int
    let losses: Int
    let globalRole: GlobalRole
    let coachSubscriptionEndsAt: Date?
    let isCoachSubscriptionPaused: Bool
    let organizerSubscriptionEndsAt: Date?
    let isOrganizerSubscriptionPaused: Bool
    let isSuspended: Bool
    let suspensionReason: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case avatarURL = "avatar_url"
        case favoritePosition = "favorite_position"
        case preferredPositions = "preferred_positions"
        case preferredFoot = "preferred_foot"
        case skillLevel = "skill_level"
        case city
        case eloRating = "elo_rating"
        case matchesPlayed = "matches_played"
        case wins
        case draws
        case losses
        case globalRole = "global_role"
        case coachSubscriptionEndsAt = "coach_subscription_ends_at"
        case isCoachSubscriptionPaused = "is_coach_subscription_paused"
        case organizerSubscriptionEndsAt = "organizer_subscription_ends_at"
        case isOrganizerSubscriptionPaused = "is_organizer_subscription_paused"
        case isSuspended = "is_suspended"
        case suspensionReason = "suspension_reason"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fullName = try container.decode(String.self, forKey: .fullName)
        email = try container.decodeIfPresent(String.self, forKey: .email) ?? ""
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        favoritePosition = try container.decodeIfPresent(String.self, forKey: .favoritePosition) ?? "Midfielder"
        preferredPositions = try container.decodeIfPresent([FootballPosition].self, forKey: .preferredPositions) ?? []
        preferredFoot = try container.decodeIfPresent(PreferredFoot.self, forKey: .preferredFoot) ?? .right
        skillLevel = try container.decodeIfPresent(Int.self, forKey: .skillLevel) ?? 5
        city = try container.decodeIfPresent(String.self, forKey: .city) ?? ""
        eloRating = try container.decodeIfPresent(Int.self, forKey: .eloRating) ?? 1400
        matchesPlayed = try container.decodeIfPresent(Int.self, forKey: .matchesPlayed) ?? 0
        wins = try container.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        draws = try container.decodeIfPresent(Int.self, forKey: .draws) ?? 0
        losses = try container.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        globalRole = try container.decodeIfPresent(GlobalRole.self, forKey: .globalRole) ?? .player
        coachSubscriptionEndsAt = try container.decodeIfPresent(Date.self, forKey: .coachSubscriptionEndsAt)
        isCoachSubscriptionPaused = try container.decodeIfPresent(Bool.self, forKey: .isCoachSubscriptionPaused) ?? false
        organizerSubscriptionEndsAt = try container.decodeIfPresent(Date.self, forKey: .organizerSubscriptionEndsAt)
        isOrganizerSubscriptionPaused = try container.decodeIfPresent(Bool.self, forKey: .isOrganizerSubscriptionPaused) ?? false
        isSuspended = try container.decodeIfPresent(Bool.self, forKey: .isSuspended) ?? false
        suspensionReason = try container.decodeIfPresent(String.self, forKey: .suspensionReason)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    func toUser(avatarImageData: Data? = nil) -> User {
        User(
            id: id,
            fullName: fullName,
            email: email,
            avatarURL: avatarURL,
            avatarImageData: avatarImageData ?? decodeAvatarData(),
            favoritePosition: favoritePosition,
            preferredPositions: preferredPositions,
            city: city,
            eloRating: eloRating,
            matchesPlayed: matchesPlayed,
            wins: wins,
            draws: draws,
            losses: losses,
            globalRole: globalRole,
            coachSubscriptionEndsAt: coachSubscriptionEndsAt,
            isCoachSubscriptionPaused: isCoachSubscriptionPaused,
            organizerSubscriptionEndsAt: organizerSubscriptionEndsAt,
            isOrganizerSubscriptionPaused: isOrganizerSubscriptionPaused,
            isSuspended: isSuspended,
            suspensionReason: suspensionReason
        )
    }

    func decodeAvatarData() -> Data? {
        guard let avatarURL, !avatarURL.isEmpty else { return nil }
        let base64: String
        if let commaIndex = avatarURL.firstIndex(of: ",") {
            base64 = String(avatarURL[avatarURL.index(after: commaIndex)...])
        } else {
            base64 = avatarURL
        }
        return Data(base64Encoded: base64)
    }
}

private struct ClubRow: Decodable {
    let id: UUID
    let name: String
    let location: String
    let phoneNumber: String?
    let bookingHint: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case location
        case phoneNumber = "phone_number"
        case bookingHint = "booking_hint"
    }

    func toClub() -> Club {
        Club(
            id: id,
            name: name,
            location: location,
            phoneNumber: phoneNumber ?? "",
            bookingHint: bookingHint ?? "Booking is currently unavailable."
        )
    }
}

private struct PracticeRow: Decodable {
    let id: UUID
    let title: String
    let location: String
    let startDate: Date
    let durationMinutes: Int
    let numberOfPlayers: Int
    let minElo: Int
    let maxElo: Int
    let isOpenJoin: Bool
    let focusArea: String
    let notes: String
    let ownerID: UUID?
    let organiserIDs: [UUID]
    let isDraft: Bool
    let isDeleted: Bool
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case location
        case startDate = "start_date"
        case durationMinutes = "duration_minutes"
        case numberOfPlayers = "number_of_players"
        case minElo = "min_elo"
        case maxElo = "max_elo"
        case isOpenJoin = "is_open_join"
        case focusArea = "focus_area"
        case notes
        case ownerID = "owner_id"
        case organiserIDs = "organiser_ids"
        case isDraft = "is_draft"
        case isDeleted = "is_deleted"
        case deletedAt = "deleted_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        location = try container.decode(String.self, forKey: .location)
        startDate = try container.decode(Date.self, forKey: .startDate)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 90
        numberOfPlayers = try container.decode(Int.self, forKey: .numberOfPlayers)
        minElo = try container.decode(Int.self, forKey: .minElo)
        maxElo = try container.decode(Int.self, forKey: .maxElo)
        isOpenJoin = try container.decode(Bool.self, forKey: .isOpenJoin)
        focusArea = try container.decodeIfPresent(String.self, forKey: .focusArea) ?? "General"
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        ownerID = try container.decodeIfPresent(UUID.self, forKey: .ownerID)
        organiserIDs = try container.decodeIfPresent([UUID].self, forKey: .organiserIDs) ?? []
        isDraft = try container.decodeIfPresent(Bool.self, forKey: .isDraft) ?? false
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

private struct CoachReviewRow: Decodable {
    let id: UUID
    let coachID: UUID
    let authorID: UUID
    let authorName: String
    let rating: Int
    let text: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case coachID = "coach_id"
        case authorID = "author_id"
        case authorName = "author_name"
        case rating
        case text
        case createdAt = "created_at"
    }

    func toReview() -> CoachReview {
        CoachReview(
            id: id,
            coachID: coachID,
            authorID: authorID,
            authorName: authorName,
            rating: rating,
            text: text,
            createdAt: createdAt
        )
    }
}

private struct CoachReviewFallbackRow: Decodable {
    let id: UUID
    let coachID: UUID
    let authorID: UUID
    let rating: Int
    let text: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case coachID = "coach_id"
        case authorID = "author_id"
        case rating
        case text
        case createdAt = "created_at"
    }
}

private struct ProfileNameRow: Decodable {
    let id: UUID
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
    }
}

private struct MatchRow: Decodable {
    let id: UUID
    let ownerID: UUID
    let organiserIDs: [UUID]
    let clubLocation: String?
    let startAt: Date
    let durationMinutes: Int
    let format: String
    let locationName: String
    let address: String?
    let maxPlayers: Int
    let isPrivateGame: Bool
    let hasCourtBooked: Bool
    let minElo: Int
    let maxElo: Int
    let isRatingGame: Bool
    let anyoneCanInvite: Bool
    let anyPlayerCanInputResults: Bool
    let entranceWithoutConfirmation: Bool
    let notes: String
    let inviteLink: String?
    let isDraft: Bool
    let isDeleted: Bool
    let deletedAt: Date?
    let status: MatchStatus
    let finalHomeScore: Int?
    let finalAwayScore: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case organiserIDs = "organiser_ids"
        case clubLocation = "club_location"
        case startAt = "start_at"
        case durationMinutes = "duration_minutes"
        case format
        case locationName = "location_name"
        case address
        case maxPlayers = "max_players"
        case isPrivateGame = "is_private_game"
        case hasCourtBooked = "has_court_booked"
        case minElo = "min_elo"
        case maxElo = "max_elo"
        case isRatingGame = "is_rating_game"
        case anyoneCanInvite = "anyone_can_invite"
        case anyPlayerCanInputResults = "any_player_can_input_results"
        case entranceWithoutConfirmation = "entrance_without_confirmation"
        case notes
        case inviteLink = "invite_link"
        case isDraft = "is_draft"
        case isDeleted = "is_deleted"
        case deletedAt = "deleted_at"
        case status
        case finalHomeScore = "final_home_score"
        case finalAwayScore = "final_away_score"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ownerID = try container.decode(UUID.self, forKey: .ownerID)
        organiserIDs = try container.decodeIfPresent([UUID].self, forKey: .organiserIDs) ?? []
        clubLocation = try container.decodeIfPresent(String.self, forKey: .clubLocation)
        startAt = try container.decode(Date.self, forKey: .startAt)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 90
        format = try container.decodeIfPresent(String.self, forKey: .format) ?? MatchFormat.fiveVFive.rawValue
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName) ?? ""
        address = try container.decodeIfPresent(String.self, forKey: .address)
        maxPlayers = try container.decodeIfPresent(Int.self, forKey: .maxPlayers) ?? MatchFormat.fiveVFive.requiredPlayers
        isPrivateGame = try container.decodeIfPresent(Bool.self, forKey: .isPrivateGame) ?? false
        hasCourtBooked = try container.decodeIfPresent(Bool.self, forKey: .hasCourtBooked) ?? false
        minElo = try container.decodeIfPresent(Int.self, forKey: .minElo) ?? 1200
        maxElo = try container.decodeIfPresent(Int.self, forKey: .maxElo) ?? 1800
        isRatingGame = try container.decodeIfPresent(Bool.self, forKey: .isRatingGame) ?? true
        anyoneCanInvite = try container.decodeIfPresent(Bool.self, forKey: .anyoneCanInvite) ?? false
        anyPlayerCanInputResults = try container.decodeIfPresent(Bool.self, forKey: .anyPlayerCanInputResults) ?? false
        entranceWithoutConfirmation = try container.decodeIfPresent(Bool.self, forKey: .entranceWithoutConfirmation) ?? false
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        inviteLink = try container.decodeIfPresent(String.self, forKey: .inviteLink)
        isDraft = try container.decodeIfPresent(Bool.self, forKey: .isDraft) ?? false
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        status = try container.decodeIfPresent(MatchStatus.self, forKey: .status) ?? .scheduled
        finalHomeScore = try container.decodeIfPresent(Int.self, forKey: .finalHomeScore)
        finalAwayScore = try container.decodeIfPresent(Int.self, forKey: .finalAwayScore)
    }
}

private struct MatchParticipantRow: Decodable {
    let matchID: UUID
    let userID: UUID
    let name: String
    let elo: Int

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case userID = "user_id"
        case name
        case elo
    }
}

private struct ParticipantHistoryRow: Decodable {
    let matchID: UUID
    let match: ParticipantHistoryMatchRow

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
        case match = "matches"
    }
}

private struct ParticipantHistoryMatchRow: Decodable {
    let startAt: Date
    let locationName: String
    let status: MatchStatus
    let finalHomeScore: Int?
    let finalAwayScore: Int?
    let notes: String

    enum CodingKeys: String, CodingKey {
        case startAt = "start_at"
        case locationName = "location_name"
        case status
        case finalHomeScore = "final_home_score"
        case finalAwayScore = "final_away_score"
        case notes
    }
}

private struct TournamentRow: Decodable {
    let id: UUID
    let title: String
    let location: String
    let startDate: Date
    let endDate: Date?
    let visibility: TournamentVisibility
    let status: TournamentStatus
    let entryFee: Double
    let maxTeams: Int
    let format: String
    let ownerID: UUID
    let organiserIDs: [UUID]
    let disputeStatus: String
    let isDeleted: Bool
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case location
        case startDate = "start_date"
        case endDate = "end_date"
        case visibility
        case status
        case entryFee = "entry_fee"
        case maxTeams = "max_teams"
        case format
        case ownerID = "owner_id"
        case organiserIDs = "organiser_ids"
        case disputeStatus = "dispute_status"
        case isDeleted = "is_deleted"
        case deletedAt = "deleted_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        location = try container.decode(String.self, forKey: .location)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        visibility = try container.decodeIfPresent(TournamentVisibility.self, forKey: .visibility) ?? .public
        status = try container.decodeIfPresent(TournamentStatus.self, forKey: .status) ?? .published
        entryFee = try container.decode(Double.self, forKey: .entryFee)
        maxTeams = try container.decode(Int.self, forKey: .maxTeams)
        format = try container.decode(String.self, forKey: .format)
        ownerID = try container.decode(UUID.self, forKey: .ownerID)
        organiserIDs = try container.decode([UUID].self, forKey: .organiserIDs)
        disputeStatus = try container.decode(String.self, forKey: .disputeStatus)
        isDeleted = try container.decode(Bool.self, forKey: .isDeleted)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

private struct TournamentTeamRow: Decodable {
    let id: UUID
    let tournamentID: UUID
    let name: String
    let colorHex: String
    let maxPlayers: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case tournamentID = "tournament_id"
        case name
        case colorHex = "color_hex"
        case maxPlayers = "max_players"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tournamentID = try container.decode(UUID.self, forKey: .tournamentID)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#2D6CC4"
        maxPlayers = try container.decode(Int.self, forKey: .maxPlayers)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

private struct TournamentTeamMemberRow: Decodable {
    let tournamentID: UUID
    let teamID: UUID
    let userID: UUID
    let positionGroup: PositionGroup
    let sortOrder: Int
    let isCaptain: Bool

    enum CodingKeys: String, CodingKey {
        case tournamentID = "tournament_id"
        case teamID = "team_id"
        case userID = "user_id"
        case positionGroup = "position_group"
        case sortOrder = "sort_order"
        case isCaptain = "is_captain"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tournamentID = try container.decode(UUID.self, forKey: .tournamentID)
        teamID = try container.decode(UUID.self, forKey: .teamID)
        userID = try container.decode(UUID.self, forKey: .userID)
        positionGroup = try container.decodeIfPresent(PositionGroup.self, forKey: .positionGroup) ?? .bench
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        isCaptain = try container.decodeIfPresent(Bool.self, forKey: .isCaptain) ?? false
    }
}

private struct TournamentMatchRow: Decodable {
    let id: UUID
    let tournamentID: UUID
    let homeTeamID: UUID
    let awayTeamID: UUID
    let startTime: Date
    let locationName: String?
    let status: TournamentMatchStatus
    let homeScore: Int?
    let awayScore: Int?
    let isCompleted: Bool
    let matchday: Int?
    let matchID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case tournamentID = "tournament_id"
        case homeTeamID = "home_team_id"
        case awayTeamID = "away_team_id"
        case startTime = "start_time"
        case locationName = "location_name"
        case status
        case homeScore = "home_score"
        case awayScore = "away_score"
        case isCompleted = "is_completed"
        case matchday
        case matchID = "match_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tournamentID = try container.decode(UUID.self, forKey: .tournamentID)
        homeTeamID = try container.decode(UUID.self, forKey: .homeTeamID)
        awayTeamID = try container.decode(UUID.self, forKey: .awayTeamID)
        startTime = try container.decode(Date.self, forKey: .startTime)
        locationName = try container.decodeIfPresent(String.self, forKey: .locationName)
        let completed = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        status = try container.decodeIfPresent(TournamentMatchStatus.self, forKey: .status) ?? (completed ? .completed : .scheduled)
        homeScore = try container.decodeIfPresent(Int.self, forKey: .homeScore)
        awayScore = try container.decodeIfPresent(Int.self, forKey: .awayScore)
        isCompleted = completed
        matchday = try container.decodeIfPresent(Int.self, forKey: .matchday)
        matchID = try container.decodeIfPresent(UUID.self, forKey: .matchID)
    }
}

private struct IDOnlyRow: Decodable {
    let id: UUID
}

private struct ProfileLookupRow: Decodable {
    let id: UUID
    let fullName: String
    let eloRating: Int

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case eloRating = "elo_rating"
    }
}

private struct TournamentTeamMemberUserRow: Decodable {
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
    }
}

private struct TournamentMatchLookupRow: Decodable {
    let matchID: UUID?

    enum CodingKeys: String, CodingKey {
        case matchID = "match_id"
    }
}

private struct MatchDetailsRow: Decodable {
    let id: UUID
    let ownerID: UUID
    let organiserIDs: [UUID]
    let locationName: String
    let startAt: Date
    let format: String
    let notes: String
    let maxPlayers: Int
    let isRatingGame: Bool
    let hasCourtBooked: Bool
    let status: MatchStatus
    let finalHomeScore: Int?
    let finalAwayScore: Int?
    let isDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case organiserIDs = "organiser_ids"
        case locationName = "location_name"
        case startAt = "start_at"
        case format
        case notes
        case maxPlayers = "max_players"
        case isRatingGame = "is_rating_game"
        case hasCourtBooked = "has_court_booked"
        case status
        case finalHomeScore = "final_home_score"
        case finalAwayScore = "final_away_score"
        case isDeleted = "is_deleted"
    }
}

private struct MatchTeamRow: Decodable {
    let id: UUID
    let name: String
    let side: String
    let maxPlayers: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case side
        case maxPlayers = "max_players"
    }
}

private struct MatchParticipantDetailsRow: Decodable {
    let userID: UUID
    let name: String
    let matchTeamID: UUID
    let elo: Int
    let positionGroup: PositionGroup
    let rsvpStatus: RSVPStatus
    let invitedAt: Date
    let waitlistedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case name
        case matchTeamID = "match_team_id"
        case elo
        case positionGroup = "position_group"
        case rsvpStatus = "rsvp_status"
        case invitedAt = "invited_at"
        case waitlistedAt = "waitlisted_at"
    }
}

private struct MatchEventRow: Decodable {
    let id: UUID
    let type: MatchEventType
    let minute: Int
    let playerID: UUID
    let createdByID: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case minute
        case playerID = "player_id"
        case createdByID = "created_by_id"
        case createdAt = "created_at"
    }
}
