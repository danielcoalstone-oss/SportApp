import Foundation

@MainActor
final class MatchDetailsViewModel: ObservableObject {
    @Published private(set) var match: Match
    @Published private(set) var isDeleted = false
    @Published var toastMessage: String?
    @Published private(set) var currentUser: User?
    @Published var didCompleteMatch = false

    private let store: MatchLocalStore
    private let notificationService: NotificationService
    private let supabaseDataService: SupabaseDataService?

    init(
        match: Match,
        store: MatchLocalStore = UserDefaultsMatchLocalStore(),
        notificationService: NotificationService = .shared,
        supabaseDataService: SupabaseDataService? = SupabaseEnvironment.shared.dataService
    ) {
        self.match = match
        self.store = store
        self.notificationService = notificationService
        self.supabaseDataService = supabaseDataService
    }

    func setCurrentUser(_ user: User?) {
        self.currentUser = user
        if let user {
            let status = match.participants.first(where: { $0.id == user.id })?.rsvpStatus
            if status == .going {
                syncReminder(for: user.id, effectiveStatus: .going)
            } else {
                notificationService.cancelMatchReminder(matchId: match.id, userId: user.id)
            }
        }
    }

    func loadPersistedState() async {
        guard let persisted = store.load(matchId: match.id) else {
            if let supabaseDataService {
                do {
                    if let backendMatch = try await supabaseDataService.fetchMatchDetails(matchID: match.id) {
                        match = backendMatch
                        isDeleted = false
                    }
                } catch {
                    toastMessage = "Failed to load backend match data: \(error.localizedDescription)"
                }
            }
            return
        }

        match.participants = persisted.participants
        match.events = persisted.events
        if !persisted.location.isEmpty {
            match.location = persisted.location
        }
        match.startTime = persisted.startTime
        match.format = persisted.format
        match.notes = persisted.notes
        match.maxPlayers = persisted.maxPlayers
        match.status = persisted.status
        match.finalHomeScore = persisted.finalHomeScore
        match.finalAwayScore = persisted.finalAwayScore
        isDeleted = persisted.isDeleted

        if let supabaseDataService {
            do {
                if let backendMatch = try await supabaseDataService.fetchMatchDetails(matchID: match.id) {
                    match = backendMatch
                    isDeleted = false
                    persist()
                } else {
                    isDeleted = true
                    persist()
                }
            } catch {
                toastMessage = "Loaded local match cache. Backend sync failed: \(error.localizedDescription)"
            }
        }
    }

    func addEvent(_ event: MatchEvent) {
        guard AccessPolicy.canEnterMatchResult(currentUser, match) else {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        match.events.append(event)
        match.events.sort { $0.minute < $1.minute }
        persist()
        AuditLogger.log(action: "match_event_added", actorId: currentUser?.id, objectId: match.id)

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.addMatchEvent(matchID: match.id, event: event)
                } catch {
                    await MainActor.run {
                        toastMessage = "Event saved locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func setRSVP(for userId: UUID, desiredStatus: RSVPStatus) {
        guard match.status != .completed else {
            toastMessage = "Match is completed. RSVP is locked."
            return
        }
        guard let currentUser else {
            toastMessage = "Please sign in to update RSVP."
            return
        }

        let isSelfUpdate = currentUser.id == userId
        if !isSelfUpdate && !AccessPolicy.canInviteToMatch(currentUser, match) {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        var participants = match.participants
        if participants.first(where: { $0.id == userId }) == nil, isSelfUpdate {
            participants.append(
                Participant(
                    id: currentUser.id,
                    name: currentUser.fullName,
                    teamId: match.homeTeam.id,
                    elo: currentUser.eloRating,
                    positionGroup: .bench,
                    rsvpStatus: .invited,
                    invitedAt: Date(),
                    waitlistedAt: nil
                )
            )
        }

        let result = MatchRSVPService.updateRSVP(
            participants: &participants,
            userId: userId,
            desiredStatus: desiredStatus,
            maxPlayers: match.maxPlayers
        )

        match.participants = participants

        if let promoted = result.promotedParticipantName {
            toastMessage = "\(promoted) moved from waitlist to going."
        } else {
            toastMessage = result.message
        }

        if currentUser.id == userId {
            syncReminder(for: currentUser.id, effectiveStatus: result.effectiveStatus)
        }

        persist()
        AuditLogger.log(action: "match_rsvp_updated", actorId: currentUser.id, objectId: match.id, metadata: ["targetUserId": userId.uuidString, "status": desiredStatus.rawValue])

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.setMatchRSVP(matchID: match.id, userID: userId, status: desiredStatus)
                } catch {
                    await MainActor.run {
                        toastMessage = "RSVP saved locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func updateMatchDetails(startTime: Date, location: String, format: String, maxPlayers: Int, notes: String) {
        guard match.status != .completed else {
            toastMessage = "Match is completed. Settings are locked."
            return
        }
        guard AccessPolicy.canEditMatch(currentUser, match) else {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        match.startTime = startTime
        match.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        match.format = format.trimmingCharacters(in: .whitespacesAndNewlines)
        match.maxPlayers = max(maxPlayers, 1)
        match.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let currentUser {
            let currentStatus = match.participants.first(where: { $0.id == currentUser.id })?.rsvpStatus
            if currentStatus == .going {
                syncReminder(for: currentUser.id, effectiveStatus: .going)
            }
        }
        persist()
        toastMessage = "Match details updated."
        AuditLogger.log(action: "match_edited", actorId: currentUser?.id, objectId: match.id)

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateMatchDetails(
                        matchID: match.id,
                        startAt: match.startTime,
                        location: match.location,
                        format: match.format,
                        maxPlayers: match.maxPlayers,
                        notes: match.notes
                    )
                } catch {
                    await MainActor.run {
                        toastMessage = "Match updated locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func inviteParticipant(name: String, elo: Int, toHomeTeam: Bool = true) {
        guard match.status != .completed else {
            toastMessage = "Match is completed. Invites are locked."
            return
        }
        guard AccessPolicy.canInviteToMatch(currentUser, match) else {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            toastMessage = "Enter a player name before inviting."
            return
        }

        let normalizedName = trimmedName.lowercased()
        let alreadyInMatch = match.participants.contains { participant in
            participant.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedName
        }
        guard !alreadyInMatch else {
            toastMessage = "This player is already in the match."
            return
        }

        if let supabaseDataService {
            Task {
                do {
                    let invited = try await supabaseDataService.inviteParticipant(
                        matchID: match.id,
                        name: trimmedName,
                        elo: max(elo, 0),
                        toHomeTeam: toHomeTeam
                    )
                    await MainActor.run {
                        appendInvitedParticipant(
                            id: invited.userID,
                            name: invited.fullName,
                            elo: invited.elo,
                            toHomeTeam: toHomeTeam
                        )
                        toastMessage = "Invite sent to \(invited.fullName)."
                        AuditLogger.log(action: "match_invite_sent", actorId: currentUser?.id, objectId: match.id, metadata: ["participantName": invited.fullName])
                    }
                } catch {
                    await MainActor.run {
                        toastMessage = error.localizedDescription
                    }
                }
            }
            return
        }

        appendInvitedParticipant(
            id: UUID(),
            name: trimmedName,
            elo: max(elo, 0),
            toHomeTeam: toHomeTeam
        )
        toastMessage = "Invite sent to \(trimmedName)."
        AuditLogger.log(action: "match_invite_sent", actorId: currentUser?.id, objectId: match.id, metadata: ["participantName": trimmedName])
    }

    func removeParticipant(participantId: UUID) {
        guard match.status != .completed else {
            toastMessage = "Match is completed. Participants are locked."
            return
        }
        guard AccessPolicy.canEditMatch(currentUser, match) else {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        guard let index = match.participants.firstIndex(where: { $0.id == participantId }) else {
            return
        }

        let removedName = match.participants[index].name
        match.participants.remove(at: index)
        persist()
        toastMessage = "\(removedName) removed from match."
        AuditLogger.log(action: "match_participant_removed", actorId: currentUser?.id, objectId: match.id, metadata: ["participantId": participantId.uuidString])

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.removeParticipant(matchID: match.id, userID: participantId)
                } catch {
                    await MainActor.run {
                        toastMessage = "Removed locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func moveParticipantToWaitlist(participantId: UUID) {
        guard match.status != .completed else {
            toastMessage = "Match is completed. Participants are locked."
            return
        }
        guard AccessPolicy.canEditMatch(currentUser, match) else {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        guard let index = match.participants.firstIndex(where: { $0.id == participantId }) else {
            return
        }

        match.participants[index].rsvpStatus = .waitlisted
        match.participants[index].waitlistedAt = Date()
        persist()
        toastMessage = "\(match.participants[index].name) moved to waitlist."
        AuditLogger.log(action: "match_participant_waitlisted", actorId: currentUser?.id, objectId: match.id, metadata: ["participantId": participantId.uuidString])

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.moveParticipantToWaitlist(matchID: match.id, userID: participantId)
                } catch {
                    await MainActor.run {
                        toastMessage = "Waitlist updated locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func rescheduleMatch(to startTime: Date) {
        guard match.status != .completed else {
            toastMessage = "Match is completed. Reschedule is locked."
            return
        }
        guard AccessPolicy.canEditMatch(currentUser, match) else {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        match.startTime = startTime
        match.status = .scheduled
        if let currentUser {
            let currentStatus = match.participants.first(where: { $0.id == currentUser.id })?.rsvpStatus
            if currentStatus == .going {
                syncReminder(for: currentUser.id, effectiveStatus: .going)
            }
        }
        persist()
        toastMessage = "Match rescheduled."
        AuditLogger.log(action: "match_rescheduled", actorId: currentUser?.id, objectId: match.id)

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateMatchDetails(
                        matchID: match.id,
                        startAt: match.startTime,
                        location: match.location,
                        format: match.format,
                        maxPlayers: match.maxPlayers,
                        notes: match.notes
                    )
                } catch {
                    await MainActor.run {
                        toastMessage = "Rescheduled locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func cancelMatch() {
        guard match.status != .completed else {
            toastMessage = "Completed match cannot be cancelled."
            return
        }
        guard AccessPolicy.canEditMatch(currentUser, match) else {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        guard !isDeleted else {
            toastMessage = "Match is already deleted."
            return
        }

        isDeleted = true
        match.status = .cancelled
        match.events = []
        match.participants = []
        if let currentUser {
            notificationService.cancelMatchReminder(matchId: match.id, userId: currentUser.id)
        }
        persist()
        toastMessage = "Match deleted."
        AuditLogger.log(action: "match_cancelled", actorId: currentUser?.id, objectId: match.id)

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.softDeleteMatch(matchID: match.id)
                } catch {
                    await MainActor.run {
                        toastMessage = "Deleted locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func completeMatch(finalHomeScore: Int, finalAwayScore: Int) {
        guard AccessPolicy.canEnterMatchResult(currentUser, match) else {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        let safeHome = max(finalHomeScore, 0)
        let safeAway = max(finalAwayScore, 0)
        match.finalHomeScore = safeHome
        match.finalAwayScore = safeAway
        match.status = .completed
        didCompleteMatch = true
        if let currentUser {
            notificationService.cancelMatchReminder(matchId: match.id, userId: currentUser.id)
        }
        persist()
        toastMessage = "Final score saved. Match marked completed."
        AuditLogger.log(action: "match_completed", actorId: currentUser?.id, objectId: match.id, metadata: ["home": "\(finalHomeScore)", "away": "\(finalAwayScore)"])

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.completeMatchAndApplyElo(
                        matchID: match.id,
                        homeScore: safeHome,
                        awayScore: safeAway
                    )
                } catch {
                    await MainActor.run {
                        toastMessage = "Score saved, but Elo sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    var inviteLink: String {
        "https://sportapp.local/invite/match/\(match.id.uuidString.lowercased())"
    }

    var goingCount: Int {
        match.participants.filter { $0.rsvpStatus == .going }.count
    }

    var spotsLeft: Int {
        max(match.maxPlayers - goingCount, 0)
    }

    var waitlistCount: Int {
        match.participants.filter { $0.rsvpStatus == .waitlisted }.count
    }

    var canCurrentUserEnterMatchResult: Bool {
        AccessPolicy.canEnterMatchResult(currentUser, match)
    }

    var canCurrentUserInviteToMatch: Bool {
        AccessPolicy.canInviteToMatch(currentUser, match)
    }

    var canCurrentUserEditMatch: Bool {
        AccessPolicy.canEditMatch(currentUser, match)
    }

    func canManageParticipant(_ participantId: UUID) -> Bool {
        guard let currentUser else { return false }
        if AccessPolicy.canEditMatch(currentUser, match) {
            return true
        }
        return currentUser.id == participantId
    }

    func participants(teamId: UUID, group: PositionGroup) -> [Participant] {
        match.participants
            .filter { $0.teamId == teamId && $0.positionGroup == group }
            .sorted { $0.name < $1.name }
    }

    func moveParticipant(participantId: UUID, toTeamId: UUID) {
        guard canManageParticipant(participantId) else {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard toTeamId == match.homeTeam.id || toTeamId == match.awayTeam.id else {
            return
        }
        guard let index = match.participants.firstIndex(where: { $0.id == participantId }) else {
            return
        }
        match.participants[index].teamId = toTeamId
        persist()

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateParticipantTeam(
                        matchID: match.id,
                        userID: participantId,
                        toHomeTeam: toTeamId == match.homeTeam.id
                    )
                } catch {
                    await MainActor.run {
                        toastMessage = "Team change saved locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func updateParticipantPositionGroup(participantId: UUID, group: PositionGroup) {
        guard canManageParticipant(participantId) else {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }
        guard let index = match.participants.firstIndex(where: { $0.id == participantId }) else {
            return
        }
        match.participants[index].positionGroup = group
        persist()

        if let supabaseDataService {
            Task {
                do {
                    try await supabaseDataService.updateParticipantPositionGroup(
                        matchID: match.id,
                        userID: participantId,
                        group: group
                    )
                } catch {
                    await MainActor.run {
                        toastMessage = "Position saved locally, but backend sync failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    func participants(for status: RSVPStatus) -> [Participant] {
        match.participants
            .filter { $0.rsvpStatus == status }
            .sorted { $0.name < $1.name }
    }

    private func persist() {
        store.save(
            matchId: match.id,
            state: MatchLocalState(
                participants: match.participants,
                events: match.events,
                location: match.location,
                startTime: match.startTime,
                format: match.format,
                notes: match.notes,
                maxPlayers: match.maxPlayers,
                status: match.status,
                finalHomeScore: match.finalHomeScore,
                finalAwayScore: match.finalAwayScore,
                isDeleted: isDeleted
            )
        )
    }

    private func appendInvitedParticipant(id: UUID, name: String, elo: Int, toHomeTeam: Bool) {
        let targetTeamId = toHomeTeam ? match.homeTeam.id : match.awayTeam.id
        let alreadyInMatch = match.participants.contains(where: { $0.id == id || $0.name.caseInsensitiveCompare(name) == .orderedSame })
        guard !alreadyInMatch else { return }

        let participant = Participant(
            id: id,
            name: name,
            teamId: targetTeamId,
            elo: max(elo, 0),
            rsvpStatus: .invited,
            invitedAt: Date()
        )
        match.participants.append(participant)
        persist()
    }

    private func syncReminder(for userId: UUID, effectiveStatus: RSVPStatus) {
        if effectiveStatus == .going {
            notificationService.scheduleMatchReminder(
                matchId: match.id,
                title: "\(match.homeTeam.name) vs \(match.awayTeam.name)",
                startTime: match.startTime,
                userId: userId
            )
        } else {
            notificationService.cancelMatchReminder(matchId: match.id, userId: userId)
        }
    }
}
