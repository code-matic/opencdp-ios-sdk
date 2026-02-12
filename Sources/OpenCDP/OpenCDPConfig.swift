import Foundation

/// Configuration for the OpenCDP SDK
public struct OpenCDPConfig: Sendable {
    /// The API key for authenticating with OpenCDP
    public let cdpApiKey: String
    
    /// The iOS App Group ID for sharing data with extensions (required for notification service extension)
    public let iOSAppGroup: String?
    
    /// Whether to enable debug logging
    public let debug: Bool
    
    /// Whether to automatically track screen views
    public let autoTrackScreens: Bool
    
    /// Whether to track application lifecycle events
    public let trackApplicationLifecycleEvents: Bool
    
    /// Whether to automatically track device attributes
    public let autoTrackDeviceAttributes: Bool
    
    /// Whether to throw errors back to the caller instead of handling them silently
    public let throwErrorsBack: Bool
    
    /// The base URL for the OpenCDP API
    public let apiBaseUrl: String

    public init(
        cdpApiKey: String,
        apiBaseUrl: String = "https://api.opencdp.io/gateway/data-gateway",
        iOSAppGroup: String? = nil,
        debug: Bool = false,
        autoTrackScreens: Bool = true,
        trackApplicationLifecycleEvents: Bool = true,
        autoTrackDeviceAttributes: Bool = true,
        throwErrorsBack: Bool = false
    ) {
        self.cdpApiKey = cdpApiKey
        self.apiBaseUrl = apiBaseUrl
        self.iOSAppGroup = iOSAppGroup
        self.debug = debug
        self.autoTrackScreens = autoTrackScreens
        self.trackApplicationLifecycleEvents = trackApplicationLifecycleEvents
        self.autoTrackDeviceAttributes = autoTrackDeviceAttributes
        self.throwErrorsBack = throwErrorsBack
    }
}
