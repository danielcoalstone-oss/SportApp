import Foundation

struct SupabaseAuthUser: Codable {
    let id: UUID
    let email: String?
}

struct SupabaseSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval?
    let user: SupabaseAuthUser
}

final class SupabaseSessionStore {
    private let defaults: UserDefaults
    private let key = "sportapp.supabase.session"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SupabaseSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SupabaseSession.self, from: data)
    }

    func save(_ session: SupabaseSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
