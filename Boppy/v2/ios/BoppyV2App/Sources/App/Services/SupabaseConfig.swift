import Foundation

struct SupabaseConfig {
    let url: URL
    let anonKey: String
    let edgeBaseURL: URL

    static func fromBundle() -> SupabaseConfig? {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let edgeString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_EDGE_BASE_URL") as? String,
            !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !anonKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !edgeString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            let url = URL(string: urlString),
            let edgeURL = URL(string: edgeString)
        else {
            return nil
        }

        let invalidMarkers = ["YOUR-", "YOUR_", "<", ">"]
        let looksTemplate = invalidMarkers.contains { marker in
            urlString.contains(marker) || edgeString.contains(marker) || anonKey.contains(marker)
        }

        if looksTemplate {
            return nil
        }

        return SupabaseConfig(url: url, anonKey: anonKey, edgeBaseURL: edgeURL)
    }
}
