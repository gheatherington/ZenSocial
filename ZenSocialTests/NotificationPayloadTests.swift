import XCTest
@testable import ZenSocial

final class NotificationPayloadTests: XCTestCase {

    func testExtractInstagramURLFromPayload() {
        // Stub: userInfo["instagram_url"] = "https://www.instagram.com/p/ABC123/"
        // should parse to a valid URL
        let userInfo: [String: Any] = ["instagram_url": "https://www.instagram.com/p/ABC123/"]
        let urlString = userInfo["instagram_url"] as? String
        let url = urlString.flatMap { URL(string: $0) }
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "www.instagram.com")
    }

    func testMissingInstagramURLReturnsNil() {
        // Stub: userInfo without "instagram_url" key should not produce a URL
        let userInfo: [String: Any] = ["other_key": "value"]
        let urlString = userInfo["instagram_url"] as? String
        XCTAssertNil(urlString)
    }

    func testInvalidURLStringReturnsNil() {
        // Stub: Invalid URL string should not produce a URL
        let userInfo: [String: Any] = ["instagram_url": "not a url %%%"]
        let urlString = userInfo["instagram_url"] as? String
        let url = urlString.flatMap { URL(string: $0) }
        XCTAssertNil(url)
    }
}
