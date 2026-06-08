import Foundation

public enum CDPError: Error, Sendable {
    case initializationError
    case invalidInput
    case networkError(String)
    case serverError(Int, String)
    case decodingError
    case validationError(String, String)
}

public enum CustomerIORegion: Sendable { case us, eu }

public enum PushClickBehaviorAndroid: Sendable {
    case resetTaskStack
    case activityPreventRestart
    case activityNoFlags
}

public struct CustomerIOConfig: Sendable {
    public let siteId: String
    public let apiKey: String
    public let region: CustomerIORegion
    public let autoTrackDeviceAttributes: Bool

    public init(
        siteId: String,
        apiKey: String,
        region: CustomerIORegion = .us,
        autoTrackDeviceAttributes: Bool = true
    ) {
        self.siteId = siteId
        self.apiKey = apiKey
        self.region = region
        self.autoTrackDeviceAttributes = autoTrackDeviceAttributes
    }
}

public struct OpenCDPConfig: Sendable {
    public let cdpApiKey: String
    public let cdpEndpoint: String?
    public let cdpFallbackEndpoints: [String]?
    public let cdpRequestTimeout: TimeInterval
    public let iOSAppGroup: String?
    public let debug: Bool
    public let autoTrackScreens: Bool
    public let trackApplicationLifecycleEvents: Bool
    public let autoTrackDeviceAttributes: Bool
    public let throwErrorsBack: Bool
    public let sendToCustomerIo: Bool
    public let customerIo: CustomerIOConfig?
    public let enableInAppMessages: Bool
    public let enableInAppRealtime: Bool
    public let inAppPollInterval: TimeInterval
    public let inAppRealtimeStaleTimeout: TimeInterval
    public let inAppRealtimeMaxBackoff: TimeInterval
    public let inAppSyncLimit: Int
    public let inAppPlatformOverride: String?
    public let inAppAppVersionOverride: String?

    public init(
        cdpApiKey: String,
        cdpEndpoint: String? = nil,
        cdpFallbackEndpoints: [String]? = nil,
        cdpRequestTimeout: TimeInterval = 30,
        iOSAppGroup: String? = nil,
        debug: Bool = false,
        autoTrackScreens: Bool = false,
        trackApplicationLifecycleEvents: Bool = true,
        autoTrackDeviceAttributes: Bool = true,
        throwErrorsBack: Bool = false,
        sendToCustomerIo: Bool = false,
        customerIo: CustomerIOConfig? = nil,
        enableInAppMessages: Bool = false,
        enableInAppRealtime: Bool = true,
        inAppPollInterval: TimeInterval = 30,
        inAppRealtimeStaleTimeout: TimeInterval = 60,
        inAppRealtimeMaxBackoff: TimeInterval = 30,
        inAppSyncLimit: Int = 10,
        inAppPlatformOverride: String? = nil,
        inAppAppVersionOverride: String? = nil
    ) {
        self.cdpApiKey = cdpApiKey
        self.cdpEndpoint = cdpEndpoint
        self.cdpFallbackEndpoints = cdpFallbackEndpoints
        self.cdpRequestTimeout = cdpRequestTimeout
        self.iOSAppGroup = iOSAppGroup
        self.debug = debug
        self.autoTrackScreens = autoTrackScreens
        self.trackApplicationLifecycleEvents = trackApplicationLifecycleEvents
        self.autoTrackDeviceAttributes = autoTrackDeviceAttributes
        self.throwErrorsBack = throwErrorsBack
        self.sendToCustomerIo = sendToCustomerIo
        self.customerIo = customerIo
        self.enableInAppMessages = enableInAppMessages
        self.enableInAppRealtime = enableInAppRealtime
        self.inAppPollInterval = inAppPollInterval
        self.inAppRealtimeStaleTimeout = inAppRealtimeStaleTimeout
        self.inAppRealtimeMaxBackoff = inAppRealtimeMaxBackoff
        self.inAppSyncLimit = inAppSyncLimit
        self.inAppPlatformOverride = inAppPlatformOverride
        self.inAppAppVersionOverride = inAppAppVersionOverride
    }
}
