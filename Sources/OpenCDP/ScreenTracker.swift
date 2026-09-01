#if canImport(UIKit)
import UIKit
import ObjectiveC

final class ScreenTracker {
    private weak var openCDP: OpenCDP?
    private var observerAdded = false

    init(openCDP: OpenCDP) {
        self.openCDP = openCDP
    }

    func start() {
        guard !observerAdded else { return }
        observerAdded = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewControllerDidAppear),
            name: NSNotification.Name("OpenCDPViewControllerDidAppear"),
            object: nil
        )
    }

    func stop() {
        if observerAdded {
            NotificationCenter.default.removeObserver(self)
            observerAdded = false
        }
    }

    @objc private func viewControllerDidAppear(_ notification: Notification) {
        guard let screen = notification.userInfo?["screen"] as? String else { return }
        openCDP?.trackScreenView(title: screen)
    }

    static func swizzleIfNeeded() {
        guard let cls = NSClassFromString("UIViewController") as? UIViewController.Type else { return }
        let originalSelector = #selector(UIViewController.viewDidAppear(_:))
        let swizzledSelector = #selector(UIViewController.opencdp_viewDidAppear(_:))
        guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
              let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension UIViewController {
    @objc func opencdp_viewDidAppear(_ animated: Bool) {
        opencdp_viewDidAppear(animated)
        guard let screen = ScreenNameResolver.resolve(
            title: title,
            navigationTitle: navigationItem.title,
            typeName: String(describing: type(of: self))
        ) else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("OpenCDPViewControllerDidAppear"),
            object: nil,
            userInfo: ["screen": screen]
        )
    }
}
#endif
