import Foundation

@MainActor
final class MatchDetailsViewModel: ObservableObject {
    @Published private(set) var match: Match
    @Published private(set) var isDeleted = false
    @Published var toastMessage: String?

    private let store: MatchLocalStore
    private let notificationService: NotificationService
    private(set) var currentUser: User?

    init(
        match: Match,
        store: MatchLocalStore = UserDefaultsMatchLocalStore(),
        notificationService: NotificationService = .shared
    ) {
        self.match = match
        self.store = store
        self.notificationService = notificationService
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

    func loadPersistedState() {
        guard let persisted = store.load(matchId: match.id) else {
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
    }

    func setRSVP(for userId: UUID, desiredStatus: RSVPStatus) {
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
    }

    func updateMatchDetails(startTime: Date, location: String, format: String, maxPlayers: Int, notes: String) {
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
    }

    func inviteParticipant(name: String, elo: Int, toHomeTeam: Bool = true) {
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

        let targetTeamId = toHomeTeam ? match.homeTeam.id : match.awayTeam.id
        let participant = Participant(
            id: UUID(),
            name: trimmedName,
            teamId: targetTeamId,
            elo: max(elo, 0),
            rsvpStatus: .invited,
            invitedAt: Date()
        )
        match.participants.append(participant)
        persist()
        toastMessage = "Invite sent to \(trimmedName)."
        AuditLogger.log(action: "match_invite_sent", actorId: currentUser?.id, objectId: match.id, metadata: ["participantName": trimmedName])
    }

    func removeParticipant(participantId: UUID) {
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
    }

    func moveParticipantToWaitlist(participantId: UUID) {
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
    }

    func rescheduleMatch(to startTime: Date) {
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
    }

    func cancelMatch() {
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
    }

    func completeMatch(finalHomeScore: Int, finalAwayScore: Int) {
        guard AccessPolicy.canEnterMatchResult(currentUser, match) else {
            toastMessage = AuthorizationUX.permissionDeniedMessage
            return
        }

        match.finalHomeScore = max(finalHomeScore, 0)
        match.finalAwayScore = max(finalAwayScore, 0)
        match.status = .completed
        if let currentUser {
            notificationService.cancelMatchReminder(matchId: match.id, userId: currentUser.id)
        }
        persist()
        toastMessage = "Final score saved. Match marked completed."
        AuditLogger.log(action: "match_completed", actorId: currentUser?.id, objectId: match.id, metadata: ["home": "\(finalHomeScore)", "away": "\(finalAwayScore)"])
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
