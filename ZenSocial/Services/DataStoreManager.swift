import WebKit

@MainActor
enum DataStoreManager {
    private static let instagramStoreID = UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!
    private static let youtubeStoreID   = UUID(uuidString: "B2C3D4E5-F6A7-8901-BCDE-F12345678901")!

    static func dataStore(for platform: Platform) -> WKWebsiteDataStore {
        switch platform {
        case .instagram:
            return WKWebsiteDataStore(forIdentifier: instagramStoreID)
        case .youtube:
            return WKWebsiteDataStore(forIdentifier: youtubeStoreID)
        }
    }
}
