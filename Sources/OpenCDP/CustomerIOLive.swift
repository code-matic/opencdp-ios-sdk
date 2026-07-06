import Foundation

#if canImport(CioDataPipelines)
import CioDataPipelines

enum CustomerIOLive {
    private static var isInitialized = false

    static func isAvailable() -> Bool { true }

    static func initialize(config: CustomerIOConfig) {
        var builder = SDKConfigBuilder(cdpApiKey: config.apiKey)
            .autoTrackDeviceAttributes(config.autoTrackDeviceAttributes)
        if config.region == .eu {
            builder = builder.region(.EU)
        }
        if let migrationSiteId = config.migrationSiteId, !migrationSiteId.isEmpty {
            builder = builder.migrationSiteId(migrationSiteId)
        }
        CustomerIO.initialize(withConfig: builder.build())
        isInitialized = true
    }

    static func identify(userId: String, traits: [String: Any]) {
        guard isInitialized else { return }
        CustomerIO.shared.identify(userId: userId, traits: traits)
    }

    static func track(eventName: String, properties: [String: Any]) {
        guard isInitialized else { return }
        CustomerIO.shared.track(name: eventName, properties: properties)
    }

    static func screen(title: String, properties: [String: Any]) {
        guard isInitialized else { return }
        CustomerIO.shared.screen(title: title, properties: properties)
    }

    static func registerDeviceToken(_ token: String) {
        guard isInitialized else { return }
        CustomerIO.shared.registerDeviceToken(token)
    }

    static func clearIdentify() {
        guard isInitialized else { return }
        CustomerIO.shared.clearIdentify()
    }
}
#else
enum CustomerIOLive {
    static func isAvailable() -> Bool { false }

    static func initialize(config: CustomerIOConfig) {
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
#endif
