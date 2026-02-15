import Foundation

struct RSVPUpdateResult {
    let effectiveStatus: RSVPStatus
    let message: String?
    let promotedParticipantName: String?
}

enum MatchRSVPService {
    static func updateRSVP(
        participants: inout [Participant],
        userId: UUID,
        desiredStatus: RSVPStatus,
        maxPlayers: Int,
        now: Date = Date()
    ) -> RSVPUpdateResult {
        guard let userIndex = participants.firstIndex(where: { $0.id == userId }) else {
            return RSVPUpdateResult(effectiveStatus: desiredStatus, message: "Participant not found.", promotedParticipantName: nil)
        }

        var participant = participants[userIndex]
        let previousStatus = participant.rsvpStatus
        var message: String?
        var promotedName: String?

        if desiredStatus == .going {
            let goingCountExcludingCurrent = participants
                .enumerated()
                .filter { idx, item in idx != userIndex && item.rsvpStatus == .going }
                .count

            if goingCountExcludingCurrent >= maxPlayers {
                participant.rsvpStatus = .waitlisted
                participant.waitlistedAt = participant.waitlistedAt ?? now
                message = "Match is full. You were added to the waitlist."
            } else {
                participant.rsvpStatus = .going
                participant.waitlistedAt = nil
            }
        } else {
            participant.rsvpStatus = desiredStatus
            if desiredStatus != .waitlisted {
                participant.waitlistedAt = nil
            } else {
                participant.waitlistedAt = participant.waitlistedAt ?? now
            }
        }

        participants[userIndex] = participant

        let didBecomeDeclined = previousStatus != .declined && participant.rsvpStatus == .declined
        if didBecomeDeclined {
            let goingCount = participants.filter { $0.rsvpStatus == .going }.count
            if goingCount < maxPlayers,
               let waitlistedIndex = oldestWaitlistedIndex(in: participants) {
                var promoted = participants[waitlistedIndex]
                promoted.rsvpStatus = .going
                promoted.waitlistedAt = nil
                participants[waitlistedIndex] = promoted
                promotedName = promoted.name
            }
        }

        return RSVPUpdateResult(effectiveStatus: participants[userIndex].rsvpStatus, message: message, promotedParticipantName: promotedName)
    }

    private static func oldestWaitlistedIndex(in participants: [Participant]) -> Int? {
        participants
            .enumerated()
            .filter { $0.element.rsvpStatus == .waitlisted }
            .min {
                let lhsDate = $0.element.waitlistedAt ?? $0.element.invitedAt
                let rhsDate = $1.element.waitlistedAt ?? $1.element.invitedAt
                return lhsDate < rhsDate
            }?
            .offset
    }
}
