import XCTest
@testable import SportApp

final class PlayerPreferredPositionsCodingTests: XCTestCase {
    func testPreferredPositionsEncodeDecode() throws {
        let player = Player(
            id: UUID(),
            name: "Test Player",
            avatarURL: "",
            positions: ["CM"],
            preferredPositions: [.cm, .dm, .am],
            preferredFoot: .right,
            skillLevel: 5,
            location: "Austin",
            createdAt: Date()
        )

        let data = try JSONEncoder().encode(player)
        let decoded = try JSONDecoder().decode(Player.self, from: data)

        XCTAssertEqual(decoded.preferredPositions, [.cm, .dm, .am])
    }
}
