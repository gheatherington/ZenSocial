import WebKit

@MainActor
enum DataStoreManager {
    private static let instagramStoreID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let youtubeStoreID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    static func dataStore(for platform: Platform) -> WKWebsiteDataStore {
        switch platform {
        case .instagram:
            return WKWebsiteDataStore(forIdentifier: instagramStoreID)
        case .youtube:
            return WKWebsiteDataStore(forIdentifier: youtubeStoreID)
        }
    }
}
