#if canImport(UIKit)
import UIKit
import UserNotifications

public enum OpenCDPPushSetup {
    /// Register for remote notifications and wire common UNUserNotificationCenter delegates.
    /// Host apps should still implement `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`
    /// and call `OpenCDP.shared.registerDeviceToken(apnsTokenString)`.
    public static func setupPushNotifications(
        application: UIApplication = .shared,
        openCDP: OpenCDP = .shared,
        requestAuthorization: Bool = true
    ) {
        if requestAuthorization {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        }
        application.registerForRemoteNotifications()
        _ = openCDP
    }
}
#endif
