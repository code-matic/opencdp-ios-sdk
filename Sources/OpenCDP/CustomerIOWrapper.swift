import Foundation

enum CustomerIOWrapper {
    static func initialize(config: CustomerIOConfig) {
        // Optional Customer.io integration — host app should link Customer.io SDK separately.
        // Mirrors Android reflection-based approach with a no-op when SDK is unavailable.
        _ = config
    }

    static func identify(userId: String, traits: [String: Any]) {
        _ = (userId, traits)
    }

    static func track(eventName: String, properties: [String: Any]) {
        _ = (eventName, properties)
    }

    static func screen(title: String, properties: [String: Any]) {
        _ = (title, properties)
    }

    static func registerDeviceToken(_ token: String) {
        _ = token
    }

    static func clearIdentify() {}
}
