import XCTest
@testable import OpenCDP

final class OpenCDPTests: XCTestCase {
    func testInitialization() {
        let config = OpenCDPConfig(cdpApiKey: "test-key")
        OpenCDP.shared.initialize(config: config)
        // Assert initialization state implicitly via no crash
        XCTAssertTrue(true)
    }
}
