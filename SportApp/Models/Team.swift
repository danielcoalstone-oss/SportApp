import Foundation

struct Team: Identifiable, Hashable {
    let id: UUID
    var name: String
    var members: [User]
    var maxPlayers: Int

    var spotsLeft: Int {
        max(maxPlayers - members.count, 0)
    }

    var isFull: Bool {
        members.count >= maxPlayers
    }
}
