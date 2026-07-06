import Foundation

/// Optional Customer.io integration. When the Customer.io SDK (`CioDataPipelines`) is linked,
/// calls are forwarded to Customer.io; otherwise this is a no-op.
enum CustomerIOWrapper {
    static func isAvailable() -> Bool {
        CustomerIOLive.isAvailable()
    }

    static func initialize(config: CustomerIOConfig) {
        CustomerIOLive.initialize(config: config)
    }

    static func identify(userId: String, traits: [String: Any]) {
        CustomerIOLive.identify(userId: userId, traits: traits)
    }

    static func track(eventName: String, properties: [String: Any]) {
        CustomerIOLive.track(eventName: eventName, properties: properties)
    }

    static func screen(title: String, properties: [String: Any]) {
        CustomerIOLive.screen(title: title, properties: properties)
    }

    static func registerDeviceToken(_ token: String) {
        CustomerIOLive.registerDeviceToken(token)
    }

    static func clearIdentify() {
        CustomerIOLive.clearIdentify()
    }
}
