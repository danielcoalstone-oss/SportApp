import Foundation

struct SupabaseConfig {
    let projectURL: URL
    let anonKey: String

    static func loadFromInfoPlist(bundle: Bundle = .main) -> SupabaseConfig? {
        guard
            let rawURL = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let rawAnonKey = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        else {
            return nil
        }

        let trimmedURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAnonKey = rawAnonKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            !trimmedURL.isEmpty,
            !trimmedAnonKey.isEmpty,
            let url = URL(string: trimmedURL)
        else {
            return nil
        }

        return SupabaseConfig(projectURL: url, anonKey: trimmedAnonKey)
    }
}
