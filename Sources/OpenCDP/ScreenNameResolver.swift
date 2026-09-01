import Foundation

/// Resolves and sanitizes screen names for auto-tracked view controllers.
/// Explicit `OpenCDP.trackScreenView(title:)` from the app always wins when
/// called manually; this helper is for UIViewController swizzle auto-track.
enum ScreenNameResolver {
    static let systemViewControllerNames: Set<String> = [
        "UINavigationController",
        "UITabBarController",
        "UISplitViewController",
        "UIPageViewController",
        "UIInputWindowController",
        "UICompatibilityInputViewController",
        "UIAlertController",
        "UIActivityViewController",
        "UIImagePickerController",
        "UISearchController",
        "UIHostingController",
    ]

    private static let technicalSubstrings = [
        "MaterialPageRoute",
        "PageBasedMaterialPageRoute",
        "ModalBottomSheetRoute",
        "<void>(",
        "Route<",
    ]

    static func sanitize(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return nil }
        if isTechnical(name) { return nil }
        return name
    }

    /// Cleans module-prefixed type names; skips UIKit containers / system VCs.
    static func sanitizeTypeName(_ raw: String) -> String? {
        var name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return nil }

        // Strip module prefix: "MyApp.ProfileViewController" → "ProfileViewController"
        if let dot = name.lastIndex(of: ".") {
            name = String(name[name.index(after: dot)...])
        }

        if systemViewControllerNames.contains(name) { return nil }
        if name.hasPrefix("_") { return nil }
        if name.hasPrefix("UI") && name.hasSuffix("Controller") { return nil }
        if isTechnical(name) { return nil }

        return name
    }

    /// Prefer title, then navigation title, else cleaned type name.
    static func resolve(title: String?, navigationTitle: String?, typeName: String) -> String? {
        if let title = sanitize(title), !title.isEmpty {
            return title
        }
        if let navTitle = sanitize(navigationTitle), !navTitle.isEmpty {
            return navTitle
        }
        return sanitizeTypeName(typeName)
    }

    private static func isTechnical(_ name: String) -> Bool {
        technicalSubstrings.contains { name.range(of: $0, options: .caseInsensitive) != nil }
    }
}
