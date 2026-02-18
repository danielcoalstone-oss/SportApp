import Foundation

struct SupabaseAuthSessionResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval?
    let user: SupabaseAuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }

    var asSession: SupabaseSession {
        SupabaseSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            user: user
        )
    }
}

final class SupabaseAuthService {
    private let client: SupabaseRESTClient

    init(client: SupabaseRESTClient) {
        self.client = client
    }

    func signIn(email: String, password: String) async throws -> SupabaseSession {
        let payload = ["email": email, "password": password]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await client.requestAuth(path: "token?grant_type=password", method: "POST", body: body)
        let response = try SupabaseJSON.decoder().decode(SupabaseAuthSessionResponse.self, from: data)
        client.saveSession(response.asSession)
        return response.asSession
    }

    func signUp(email: String, password: String) async throws -> SupabaseSession? {
        let payload = ["email": email, "password": password]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let data = try await client.requestAuth(path: "signup", method: "POST", body: body)

        if let sessionResponse = try? SupabaseJSON.decoder().decode(SupabaseAuthSessionResponse.self, from: data) {
            let session = sessionResponse.asSession
            client.saveSession(session)
            return session
        }

        return nil
    }

    func signOut() async {
        _ = try? await client.requestAuth(path: "logout", method: "POST", body: nil, useAccessToken: true)
        client.clearSession()
    }

    func currentUser() async throws -> SupabaseAuthUser {
        let data = try await client.requestAuth(path: "user", method: "GET", body: nil, useAccessToken: true)
        return try SupabaseJSON.decoder().decode(SupabaseAuthUser.self, from: data)
    }

    var hasSession: Bool {
        client.currentSession != nil
    }
}
