import XCTest
@testable import OpenCDP

final class OpenCDPTests: XCTestCase {
    func testInitialization() {
        let config = OpenCDPConfig(cdpApiKey: "test-key")
        OpenCDP.shared.initialize(config: config)
        XCTAssertTrue(true)
    }

    func testThrowErrorsBack_rejectsEmptyIdentifier() {
        let config = OpenCDPConfig(cdpApiKey: "test-key", throwErrorsBack: true)
        OpenCDP.shared.initialize(config: config, shouldReinitialize: true)
        XCTAssertThrowsError(try OpenCDP.shared.identify(identifier: "")) { error in
            guard let cdpError = error as? CDPError,
                  case .validationError(let field, _) = cdpError else {
                return XCTFail("Expected validationError, got \(error)")
            }
            XCTAssertEqual(field, "identifier")
        }
    }

    func testThrowErrorsBack_rejectsEmptyEventName() {
        let config = OpenCDPConfig(cdpApiKey: "test-key", throwErrorsBack: true)
        OpenCDP.shared.initialize(config: config, shouldReinitialize: true)
        XCTAssertThrowsError(try OpenCDP.shared.track(eventName: "")) { error in
            guard let cdpError = error as? CDPError,
                  case .validationError(let field, _) = cdpError else {
                return XCTFail("Expected validationError, got \(error)")
            }
            XCTAssertEqual(field, "eventName")
        }
    }

    func testThrowErrorsBack_logsWhenDisabled() {
        let config = OpenCDPConfig(cdpApiKey: "test-key", throwErrorsBack: false)
        OpenCDP.shared.initialize(config: config, shouldReinitialize: true)
        XCTAssertNoThrow(try OpenCDP.shared.identify(identifier: ""))
    }

    func testParseImageUrl_returnsTrimmedUrl() {
        let data = ["image_url": "  https://cdn.example.com/push.jpg  "]
        XCTAssertEqual(
            OpenCDPPushPayload.parseImageUrl(data),
            "https://cdn.example.com/push.jpg"
        )
    }

    func testParseImageUrl_prependsHttpsWhenSchemeMissing() {
        let data = ["image_url": "cdn.example.com/push.jpg"]
        XCTAssertEqual(
            OpenCDPPushPayload.parseImageUrl(data),
            "https://cdn.example.com/push.jpg"
        )
    }

    func testParseImageUrl_returnsNilWhenMissingOrBlank() {
        XCTAssertNil(OpenCDPPushPayload.parseImageUrl([:]))
        XCTAssertNil(OpenCDPPushPayload.parseImageUrl(["image_url": ""]))
        XCTAssertNil(OpenCDPPushPayload.parseImageUrl(["image_url": "   "]))
    }

    func testNormalizeImageUrl_preservesExistingScheme() {
        XCTAssertEqual(
            OpenCDPPushPayload.normalizeImageUrl("https://cdn.example.com/push.jpg"),
            "https://cdn.example.com/push.jpg"
        )
        XCTAssertEqual(
            OpenCDPPushPayload.normalizeImageUrl("http://cdn.example.com/push.jpg"),
            "http://cdn.example.com/push.jpg"
        )
    }

    func testPushExtensionHelperParseImageUrl_fromUserInfo() {
        let userInfo: [AnyHashable: Any] = ["image_url": "cdn.example.com/img.png"]
        XCTAssertEqual(
            OpenCdpPushExtensionHelper.parseImageUrl(from: userInfo),
            "https://cdn.example.com/img.png"
        )
    }
}
