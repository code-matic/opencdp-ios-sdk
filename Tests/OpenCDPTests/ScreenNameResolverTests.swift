import XCTest
@testable import OpenCDP

final class ScreenNameResolverTests: XCTestCase {
    func testSanitizeRejectsEmpty() {
        XCTAssertNil(ScreenNameResolver.sanitize(nil))
        XCTAssertNil(ScreenNameResolver.sanitize(""))
        XCTAssertNil(ScreenNameResolver.sanitize("   "))
    }

    func testSanitizeAllowsReadableNames() {
        XCTAssertEqual(ScreenNameResolver.sanitize("  Home  "), "Home")
        XCTAssertEqual(ScreenNameResolver.sanitize("/checkout"), "/checkout")
    }

    func testSanitizeRejectsTechnicalDumps() {
        XCTAssertNil(ScreenNameResolver.sanitize("_PageBasedMaterialPageRoute<void>(...)"))
        XCTAssertNil(ScreenNameResolver.sanitize("MaterialPageRoute<dynamic>"))
    }

    func testSanitizeTypeNameSkipsSystemControllers() {
        XCTAssertNil(ScreenNameResolver.sanitizeTypeName("UINavigationController"))
        XCTAssertNil(ScreenNameResolver.sanitizeTypeName("UITabBarController"))
        XCTAssertNil(ScreenNameResolver.sanitizeTypeName("UIInputWindowController"))
        XCTAssertNil(ScreenNameResolver.sanitizeTypeName("_PrivateVC"))
    }

    func testSanitizeTypeNameStripsModuleAndAllowsAppVCs() {
        XCTAssertEqual(
            ScreenNameResolver.sanitizeTypeName("MyApp.ProfileViewController"),
            "ProfileViewController"
        )
        XCTAssertEqual(
            ScreenNameResolver.sanitizeTypeName("HomeViewController"),
            "HomeViewController"
        )
    }

    func testResolvePrefersTitleOverTypeName() {
        XCTAssertEqual(
            ScreenNameResolver.resolve(
                title: "Profile",
                navigationTitle: nil,
                typeName: "ProfileViewController"
            ),
            "Profile"
        )
    }

    func testResolveUsesNavigationItemTitle() {
        XCTAssertEqual(
            ScreenNameResolver.resolve(
                title: nil,
                navigationTitle: "Settings",
                typeName: "SettingsViewController"
            ),
            "Settings"
        )
    }
}
