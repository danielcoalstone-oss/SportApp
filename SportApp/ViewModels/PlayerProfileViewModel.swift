import Foundation

enum MainPosition: String, CaseIterable, Identifiable {
    case goalkeeper = "Goalkeeper"
    case defender = "Defender"
    case midfielder = "Midfielder"
    case forward = "Forward"

    var id: String { rawValue }

    static func from(stored: String) -> MainPosition {
        switch stored.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "goalkeeper", "gk":
            return .goalkeeper
        case "defender", "cb", "lb", "rb", "lwb", "rwb":
            return .defender
        case "forward", "lw", "rw", "st", "cf", "ss":
            return .forward
        default:
            return .midfielder
        }
    }
}

@MainActor
final class PlayerProfileViewModel: ObservableObject {
    @Published var name = ""
    @Published var avatarImageData: Data?
    @Published var mainPosition: MainPosition = .midfielder
    @Published var preferredPositions: [FootballPosition] = []
    @Published var preferredFoot: PreferredFoot = .right
    @Published var skillLevel = 5.0
    @Published var location = ""
    @Published var createdAt = Date()
    @Published var matchHistory: [PlayerMatch] = []
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let playerID: UUID
    private let repository: any PlayerProfileRepository

    init(playerID: UUID, repository: any PlayerProfileRepository, seedPlayer: Player? = nil) {
        self.playerID = playerID
        self.repository = repository
        if let seedPlayer {
            apply(seedPlayer)
        }
    }

    func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            async let playerTask = repository.fetchPlayer(id: playerID)
            async let matchesTask = repository.fetchMatchHistory(playerID: playerID)

            let player = try await playerTask
            let matches = try await matchesTask

            apply(player)
            matchHistory = matches.sorted { $0.date > $1.date }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func saveProfile() async -> Player? {
        isSaving = true
        errorMessage = nil

        let updatedPlayer = Player(
            id: playerID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarURL: "",
            avatarImageData: avatarImageData,
            positions: [mainPosition.rawValue],
            preferredPositions: preferredPositions,
            preferredFoot: preferredFoot,
            skillLevel: Int(skillLevel.rounded()),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: createdAt
        )

        do {
            let saved = try await repository.updatePlayer(updatedPlayer)
            apply(saved)
            isSaving = false
            return saved
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
        return nil
    }

    private func apply(_ player: Player) {
        name = player.name
        avatarImageData = player.avatarImageData
        mainPosition = MainPosition.from(stored: player.positions.first ?? "")
        preferredPositions = player.preferredPositions
        preferredFoot = player.preferredFoot
        skillLevel = Double(player.skillLevel)
        location = player.location
        createdAt = player.createdAt
    }

    var upcomingMatches: [PlayerMatch] {
        let now = Date()
        return matchHistory
            .filter { !$0.isCompleted || $0.date >= now }
            .sorted { $0.date < $1.date }
    }

    var pastMatches: [PlayerMatch] {
        let now = Date()
        return matchHistory
            .filter { $0.isCompleted && $0.date < now }
            .sorted { $0.date > $1.date }
    }

    var completedMatchesPlayed: Int {
        completedMatches.count
    }

    var winsCount: Int {
        completedMatches.filter { $0.outcome == .win }.count
    }

    var drawsCount: Int {
        completedMatches.filter { $0.outcome == .draw }.count
    }

    var lossesCount: Int {
        completedMatches.filter { $0.outcome == .loss }.count
    }

    private var completedMatches: [PlayerMatch] {
        matchHistory.filter { $0.isCompleted && $0.outcome != nil }
    }
}
