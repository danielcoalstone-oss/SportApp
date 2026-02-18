import Foundation

final class SupabaseEnvironment {
    static let shared = SupabaseEnvironment()

    let config: SupabaseConfig?
    let sessionStore: SupabaseSessionStore
    let restClient: SupabaseRESTClient?
    let authService: SupabaseAuthService?
    let dataService: SupabaseDataService?

    private init() {
        let config = SupabaseConfig.loadFromInfoPlist()
        self.config = config
        self.sessionStore = SupabaseSessionStore()

        if let config {
            let client = SupabaseRESTClient(config: config, sessionStore: sessionStore)
            self.restClient = client
            self.authService = SupabaseAuthService(client: client)
            self.dataService = SupabaseDataService(client: client)
        } else {
            self.restClient = nil
            self.authService = nil
            self.dataService = nil
        }
    }

    var isConfigured: Bool {
        authService != nil && dataService != nil
    }
}
