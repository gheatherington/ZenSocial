import XCTest
@testable import ZenSocial

final class APNsTokenTests: XCTestCase {

    func testDeviceTokenFormattedAsHexString() {
        // Stub: Data bytes [0xDE, 0xAD, 0xBE, 0xEF] -> "deadbeef"
        let tokenData = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let formatted = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        XCTAssertEqual(formatted, "deadbeef")
    }

    func testEmptyTokenData() {
        // Stub: Empty Data -> empty string
        let tokenData = Data()
        let formatted = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        XCTAssertEqual(formatted, "")
    }
}
