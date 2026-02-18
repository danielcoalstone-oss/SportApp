import Foundation

enum SupabaseClientError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case invalidResponse
    case httpError(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured."
        case .notAuthenticated:
            return "You need to sign in first."
        case .invalidResponse:
            return "Invalid server response."
        case .httpError(let status, let message):
            return "Server error (\(status)): \(message)"
        }
    }
}

final class SupabaseRESTClient {
    private let config: SupabaseConfig
    private let sessionStore: SupabaseSessionStore
    private let urlSession: URLSession

    init(config: SupabaseConfig, sessionStore: SupabaseSessionStore, urlSession: URLSession = .shared) {
        self.config = config
        self.sessionStore = sessionStore
        self.urlSession = urlSession
    }

    var baseURL: URL {
        config.projectURL
    }

    var currentSession: SupabaseSession? {
        sessionStore.load()
    }

    func saveSession(_ session: SupabaseSession) {
        sessionStore.save(session)
    }

    func clearSession() {
        sessionStore.clear()
    }

    func requestAuth(path: String, method: String, body: Data? = nil, useAccessToken: Bool = false) async throws -> Data {
        var components = URLComponents(url: config.projectURL, resolvingAgainstBaseURL: false)
        let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let endpoint = normalized.split(separator: "?").first.map(String.init) ?? normalized
        components?.path = "/auth/v1/\(endpoint)"

        if let questionMark = normalized.firstIndex(of: "?") {
            let query = String(normalized[normalized.index(after: questionMark)...])
            components?.percentEncodedQuery = query
        }

        guard let url = components?.url else {
            throw SupabaseClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if useAccessToken {
            let token = try await validAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body
        do {
            return try await perform(request)
        } catch SupabaseClientError.httpError(let status, _) where useAccessToken && status == 401 {
            let refreshedToken = try await forceRefreshAccessToken()
            request.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
            return try await perform(request)
        }
    }

    func requestPostgrest(pathAndQuery: String, method: String = "GET", body: Data? = nil, authenticated: Bool = true, extraHeaders: [String: String] = [:]) async throws -> Data {
        var components = URLComponents(url: config.projectURL.appending(path: "rest/v1"), resolvingAgainstBaseURL: false)
        let normalized = pathAndQuery.hasPrefix("/") ? String(pathAndQuery.dropFirst()) : pathAndQuery
        components?.path = "/rest/v1/\(normalized.split(separator: "?").first ?? "")"

        if let questionMark = normalized.firstIndex(of: "?") {
            let query = String(normalized[normalized.index(after: questionMark)...])
            components?.percentEncodedQuery = query
        }

        guard let url = components?.url else {
            throw SupabaseClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated {
            let token = try await validAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        for (header, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        request.httpBody = body
        do {
            return try await perform(request)
        } catch SupabaseClientError.httpError(let status, _) where authenticated && status == 401 {
            let refreshedToken = try await forceRefreshAccessToken()
            request.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
            return try await perform(request)
        }
    }

    func requestRPC(function: String, body: Data? = nil, authenticated: Bool = true, extraHeaders: [String: String] = [:]) async throws -> Data {
        let endpoint = function.hasPrefix("/") ? String(function.dropFirst()) : function
        let url = config.projectURL.appending(path: "rest/v1/rpc/\(endpoint)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if authenticated {
            let token = try await validAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        for (header, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        request.httpBody = body
        do {
            return try await perform(request)
        } catch SupabaseClientError.httpError(let status, _) where authenticated && status == 401 {
            let refreshedToken = try await forceRefreshAccessToken()
            request.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
            return try await perform(request)
        }
    }

    func requestStorage(
        path: String,
        method: String,
        body: Data? = nil,
        contentType: String = "application/octet-stream",
        authenticated: Bool = true,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = config.projectURL.appending(path: "storage/v1/\(normalized)")

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        if authenticated {
            let token = try await validAccessToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        for (header, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: header)
        }

        request.httpBody = body
        do {
            return try await perform(request)
        } catch SupabaseClientError.httpError(let status, _) where authenticated && status == 401 {
            let refreshedToken = try await forceRefreshAccessToken()
            request.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
            return try await perform(request)
        }
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseClientError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseClientError.httpError(status: http.statusCode, message: message)
        }

        return data
    }

    private func validAccessToken() async throws -> String {
        guard let session = currentSession else {
            throw SupabaseClientError.notAuthenticated
        }

        if let expiresAt = session.expiresAt {
            let nowPlusBuffer = Date().timeIntervalSince1970 + 60
            if nowPlusBuffer >= expiresAt {
                return try await forceRefreshAccessToken()
            }
        }

        return session.accessToken
    }

    private func forceRefreshAccessToken() async throws -> String {
        guard let session = currentSession else {
            throw SupabaseClientError.notAuthenticated
        }
        let refreshed = try await refreshSession(refreshToken: session.refreshToken)
        saveSession(refreshed)
        return refreshed.accessToken
    }

    private func refreshSession(refreshToken: String) async throws -> SupabaseSession {
        let url = config.projectURL.appending(path: "auth/v1/token")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let tokenURL = components?.url else {
            throw SupabaseClientError.invalidResponse
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])

        let data = try await perform(request)
        let response = try SupabaseJSON.decoder().decode(SupabaseAuthSessionResponse.self, from: data)
        return response.asSession
    }
}

enum SupabaseJSON {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let value = Self.fractionalDateFormatter.date(from: string) ?? Self.standardDateFormatter.date(from: string) {
                return value
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static let standardDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
